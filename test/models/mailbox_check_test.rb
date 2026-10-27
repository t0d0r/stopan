require "test_helper"

# Fetching from an organization's IMAP mailbox with a fake server
# (specs/organization-mail.md "Fetching").
class MailboxCheckTest < ActiveSupport::TestCase
  class FakeIMAP
    Message = Struct.new(:attr)
    class << self
      attr_accessor :mailbox, :seen, :logins, :fail_login
    end

    def initialize(host, port:, ssl:, open_timeout:)
      @host = host
    end

    def capable?(_name) = false
    def login(user, password)
      raise Net::IMAP::NoResponseError.new(Struct.new(:data).new(Struct.new(:text).new("bad credentials"))) if self.class.fail_login

      self.class.logins << [ user, password ]
    end

    def select(_folder) = nil
    def examine(_folder) = nil
    def uid_search(_keys) = self.class.mailbox.keys - self.class.seen
    def uid_fetch(uid, _attr) = [ Message.new({ "BODY[]" => self.class.mailbox.fetch(uid) }) ]
    def uid_store(uid, _op, _flags) = self.class.seen << uid
    def logout = nil
    def disconnect = nil
    def disconnected? = true
  end

  setup do
    @org = organizations(:acme)
    @org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk", imap_password: "pw",
                 mailbox_address: "support@acme.example")
    FakeIMAP.mailbox = {}
    FakeIMAP.seen = []
    FakeIMAP.logins = []
    FakeIMAP.fail_login = false
  end

  def raw(subject) = Mail.new(from: "x#{subject.hash.abs}@example.com", to: "support@acme.example", subject: subject, body: "Text").to_s

  test "unseen messages become tickets and are marked seen, at most 50 per check" do
    (1..52).each { |uid| FakeIMAP.mailbox[uid] = raw("Message #{uid}") }
    assert_difference -> { Ticket.count }, 50 do
      assert_equal 50, MailboxCheck.new(@org, imap_class: FakeIMAP).run
    end
    assert_equal (1..50).to_a, FakeIMAP.seen
    assert_equal [ [ "desk", "pw" ] ], FakeIMAP.logins
    @org.reload
    assert_equal 50, @org.imap_messages_count
    assert_nil @org.imap_last_error
    assert @org.imap_last_checked_at

    assert_equal 2, MailboxCheck.new(@org, imap_class: FakeIMAP).run
    assert_equal 0, MailboxCheck.new(@org, imap_class: FakeIMAP).run
  end

  test "a broken message is marked seen and recorded; the rest go on" do
    FakeIMAP.mailbox[1] = raw("Fine")
    FakeIMAP.mailbox[2] = raw("Broken")
    MailboxMessage.class_eval { alias_method :original_process, :process }
    MailboxMessage.define_method(:process) { mail.subject == "Broken" ? raise("boom") : original_process }
    MailboxCheck.new(@org, imap_class: FakeIMAP).run
    assert_equal [ 1, 2 ], FakeIMAP.seen
    assert_equal "RuntimeError: boom", @org.reload.imap_last_error
  ensure
    MailboxMessage.class_eval do
      alias_method :process, :original_process
      remove_method :original_process
    end
  end

  test "a failed login is recorded, and the probe raises it" do
    FakeIMAP.fail_login = true
    assert_equal 0, MailboxCheck.new(@org, imap_class: FakeIMAP).run
    assert_match(/bad credentials/, @org.reload.imap_last_error)
    assert_raises(Net::IMAP::NoResponseError) { MailboxCheck.new(@org, imap_class: FakeIMAP).probe }
  end

  test "the probe counts unseen messages without taking them in" do
    FakeIMAP.mailbox[7] = raw("Waiting")
    assert_no_difference -> { Ticket.count } do
      assert_equal 1, MailboxCheck.new(@org, imap_class: FakeIMAP).probe
    end
    assert_empty FakeIMAP.seen
  end
end
