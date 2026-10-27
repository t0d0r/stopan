require "test_helper"

# The headers of the mail a ticket came from (specs/organization-mail.md "Mail details").
class MailHeadersTest < ActionDispatch::IntegrationTest
  setup do
    @org = organizations(:acme)
    @org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk",
                 mailbox_address: "support@acme.example")
  end

  def incoming
    mail = Mail.new do
      from "=?UTF-8?B?0JjQstCw0L0=?= <ivan@example.com>"
      to "support@acme.example, \"Other Desk\" <other@example.com>"
      cc "boss@example.com"
      reply_to "replies@example.com"
      date Time.zone.parse("2026-10-27 10:00 +02:00")
      message_id "<m-1@example.com>"
      subject "Fwd: Bread slicer jams"
      body "It jams."
    end
    MailboxMessage.new(@org, mail.to_s).process
    Ticket.order(:id).last
  end

  test "a ticket from mail keeps the important headers, decoded" do
    headers = incoming.mail_headers
    assert_equal [ "Иван <ivan@example.com>" ], headers["from"]
    assert_equal [ "support@acme.example", "Other Desk <other@example.com>" ], headers["to"]
    assert_equal [ "boss@example.com" ], headers["cc"]
    assert_equal "replies@example.com", headers["reply_to"]
    assert_equal "Fwd: Bread slicer jams", headers["subject"]
    assert_equal "m-1@example.com", headers["message_id"]
    assert_equal Time.iso8601("2026-10-27T10:00:00+02:00"), Time.iso8601(headers["date"])
  end

  test "staff see them at the start of the request; the requester and shared pages do not" do
    ticket = incoming
    sign_in users(:agent)
    get ticket_url(ticket)
    assert_select "#description .message__body > .mail-headers:first-child" do
      assert_select ".mail-headers__from strong", "Иван"
      assert_select ".mail-headers__address", "<ivan@example.com>"
      assert_select ".mail-headers__to", /To: support@acme\.example, Other Desk <other@example\.com>/
      assert_select ".mail-headers__to", /Cc: boss@example\.com/
      assert_select "time.mail-headers__date[datetime]"
      assert_select "details.mail-headers__details summary", "Details"
      assert_select ".mail-headers__list dd", "replies@example.com"
      assert_select ".mail-headers__list dd", "Fwd: Bread slicer jams"
      assert_select ".mail-headers__list dd.mail-headers__id", "m-1@example.com"
    end

    sign_in ticket.requester
    get ticket_url(ticket)
    assert_response :success
    assert_select ".mail-headers", 0
    assert_not_includes response.body, "boss@example.com"

    ticket.share!(actor: users(:agent))
    get shared_ticket_url(ticket.share_token)
    assert_select ".mail-headers", 0
    assert_not_includes response.body, "boss@example.com"
  end

  test "tickets without headers show no block" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select ".mail-headers", 0
  end
end
