require "test_helper"

# Mail to an organization's mailbox becomes tickets and replies
# (specs/organization-mail.md "Processing a message").
class MailboxMessageTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @org = organizations(:acme)
    @org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk",
                 mailbox_address: "support@acme.example")
  end

  def email(from: "Ivan Ivanov <ivan@example.com>", subject: "Bread slicer jams", body: "It jams every morning.", **headers, &block)
    mail = Mail.new do
      from from
      to "support@acme.example"
      subject subject
      body body
    end
    headers.each { |name, value| mail[name.to_s.tr("_", "-")] = value }
    block&.call(mail)
    mail.to_s
  end

  def process(raw) = MailboxMessage.new(@org, raw).process

  test "an unknown sender gets a requester account, a ticket and a confirmation" do
    result = nil
    assert_difference -> { User.count } => 1, -> { Ticket.count } => 1 do
      perform_enqueued_jobs { result = process(email(subject: "Re: Fwd:  Bread slicer jams")) }
    end
    assert_equal :ticket, result
    ticket = Ticket.order(:id).last
    user = User.find_by!(email: "ivan@example.com")
    assert_equal [ "Ivan Ivanov", false, true ], [ user.name, user.password_chosen?, user.member_of?(@org) ]
    assert_equal [ "Bread slicer jams", "It jams every morning.", "email", user ],
                 [ ticket.subject, ticket.description, ticket.source, ticket.requester ]
    assert ActionMailer::Base.deliveries.any? { |m| m.to == [ "ivan@example.com" ] && m.subject.include?("We received") }
  end

  test "a reply by the requester becomes a public reply without the quote" do
    ticket = tickets(:printer)
    body = "Still blank after the new roll.\n\nOn Mon, 26 Oct 2026, Service desk <support@acme.example> wrote:\n> Please try a new roll."
    assert_difference -> { ticket.comments.count } do
      assert_equal :reply, process(email(from: users(:anna).email, subject: "Re: [Stopan ##{ticket.number}] Reply: printer", body: body))
    end
    comment = ticket.comments.last
    assert_equal [ "Still blank after the new roll.", "email", false ], [ comment.body, comment.source, comment.internal? ]
    assert_equal users(:anna), comment.author
  end

  test "a reply is also matched by References" do
    ticket = tickets(:printer)
    raw = email(from: users(:anna).email, subject: "Re: printer", body: "Thanks!",
                references: "<ticket-#{ticket.number}@example.com>")
    assert_equal :reply, process(raw)
  end

  test "staff reply by email to open tickets only; never start one" do
    ticket = tickets(:printer)
    assert_equal :reply, process(email(from: users(:agent).email, subject: "[Stopan ##{ticket.number}]", body: "On it."))
    assert_equal users(:agent), ticket.comments.last.author
    assert_equal :ignored, process(email(from: users(:agent).email, subject: "New thing"))
  end

  test "someone else quoting a ticket number starts their own ticket; closed tickets too" do
    assert_equal :ticket, process(email(from: users(:boris).email, subject: "[Stopan ##{tickets(:printer).number}] me too"))
    assert_equal users(:boris), Ticket.order(:id).last.requester
    assert_equal :ticket, process(email(from: users(:anna).email, subject: "Re: [Stopan ##{tickets(:old_question).number}]"))
  end

  test "automatic mail, own mail and deactivated senders are skipped" do
    assert_no_difference -> { Ticket.count } do
      assert_equal :skipped, process(email(auto_submitted: "auto-replied"))
      assert_equal :skipped, process(email(precedence: "bulk"))
      assert_equal :skipped, process(email(x_autoreply: "yes"))
      assert_equal :skipped, process(email(list_id: "<news.example.com>"))
      assert_equal :skipped, process(email(from: "MAILER-DAEMON@example.com"))
      assert_equal :skipped, process(email(from: "support@acme.example"))
      users(:boris).update!(deactivated_at: Time.current)
      assert_equal :ignored, process(email(from: users(:boris).email))
    end
  end

  test "HTML mail becomes text; empty mail gets placeholders" do
    raw = email(body: nil) do |mail|
      mail.html_part = Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body "<p>Hello <b>desk</b></p><script>alert(1)</script><p>Line two<br>Line three</p>"
      end
    end
    process(raw)
    assert_equal "Hello desk\nLine two\nLine three", Ticket.order(:id).last.description

    process(email(subject: "", body: ""))
    assert_equal [ "(no subject)", "(no text)" ], Ticket.order(:id).last.slice(:subject, :description).values
  end

  test "allowed attachments are kept, others named in the text" do
    raw = email do |mail|
      mail.add_file(filename: "log.txt", content: "error 42\n")
      mail.add_file(filename: "virus.exe", content: "MZ\x90\x00binary")
    end
    process(raw)
    ticket = Ticket.order(:id).last
    assert_equal [ "log.txt" ], ticket.files.map { |file| file.filename.to_s }
    assert_includes ticket.description, "Some attachments were not accepted: virus.exe"
  end
end
