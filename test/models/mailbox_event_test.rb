require "test_helper"

# specs/status.md "Mail in"
class MailboxEventTest < ActiveSupport::TestCase
  setup do
    @org = organizations(:acme)
    @org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk",
                 mailbox_address: "support@acme.example")
  end

  def email(from:, subject: "Bread slicer jams", body: "It jams.", **headers)
    mail = Mail.new
    mail.from = from
    mail.to = "support@acme.example"
    mail.subject = subject
    mail.body = body
    headers.each { |name, value| mail[name.to_s.tr("_", "-")] = value }
    mail.to_s
  end

  def process(raw) = MailboxMessage.new(@org, raw).process

  def last = MailboxEvent.newest_first.first

  test "a new ticket and a reply are recorded with their ticket" do
    assert_equal :ticket, process(email(from: "Ivan <ivan@example.com>", subject: "  A   long subject #{'x' * 200}"))
    ticket = Ticket.order(:id).last
    assert_equal [ "ticket", nil, "ivan@example.com", ticket.id ], [ last.result, last.reason, last.sender, last.ticket_id ]
    assert_equal MailboxEvent::SUBJECT_LIMIT, last.subject.length
    assert last.subject.start_with?("A long subject")

    printer = tickets(:printer)
    assert_equal :reply, process(email(from: users(:anna).email, subject: "Re: [Stopan ##{printer.number}] Reply: printer"))
    assert_equal [ "reply", printer.id ], [ last.result, last.ticket_id ]
  end

  test "skipped and ignored mail is recorded with the reason" do
    { email(from: "robot@example.com", auto_submitted: "auto-replied") => [ "skipped", "automatic" ],
      email(from: "support@acme.example") => [ "skipped", "own_address" ],
      email(from: users(:agent).email) => [ "ignored", "staff_sender_without_a_ticket" ],
      email(from: users(:retired).email) => [ "ignored", "deactivated_sender" ] }.each do |raw, expected|
      assert_no_difference("Ticket.count") { process(raw) }
      assert_equal expected, [ last.result, last.reason ]
      assert I18n.exists?("ui.status.mail.reasons.#{last.reason}"), last.reason
    end
    assert_equal users(:agent).email, MailboxEvent.where(reason: "staff_sender_without_a_ticket").sole.sender
  end

  test "a message that raises is recorded as failed by its error class" do
    message = MailboxMessage.new(@org, email(from: "ivan@example.com"))
    message.record_failure(ActiveRecord::RecordInvalid.new(Ticket.new))
    assert_equal [ "failed", "ActiveRecord::RecordInvalid", "ivan@example.com" ], [ last.result, last.reason, last.sender ]
  end

  test "only the newest per organization are kept, and they go with the organization" do
    other = organizations(:globex)
    MailboxEvent.record(other, result: "skipped", reason: "automatic")
    (MailboxEvent::KEEP + 5).times { |i| MailboxEvent.record(@org, result: "skipped", reason: "automatic", subject: "n#{i}") }
    assert_equal MailboxEvent::KEEP, MailboxEvent.where(organization: @org).count
    assert_equal "n#{MailboxEvent::KEEP + 4}", MailboxEvent.where(organization: @org).newest_first.first.subject
    assert_equal "n5", MailboxEvent.where(organization: @org).order(:id).first.subject
    assert_equal 1, MailboxEvent.where(organization: other).count

    organization = Organization.create!(name: "Shortlived")
    MailboxEvent.record(organization, result: "skipped", reason: "automatic")
    assert_difference("MailboxEvent.count", -1) { organization.destroy! }
  end

  test "recording never raises" do
    assert_nothing_raised { MailboxEvent.record(@org, result: "nonsense") }
    assert_equal 0, MailboxEvent.where(result: "nonsense").count
  end
end
