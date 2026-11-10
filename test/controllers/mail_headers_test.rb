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

  def reply_to_ticket(ticket)
    number = ticket.number
    sender = ticket.requester.email
    mail = Mail.new do
      from sender
      to "support@acme.example"
      cc "boss@example.com"
      date Time.zone.parse("2026-10-28 09:30 +01:00")
      message_id "<r-1@example.com>"
      subject "Re: [Stopan ##{number}] Bread slicer jams"
      body "Still jams.\n\nOn Tue, 27 Oct 2026, Service desk <support@acme.example> wrote:\n> It jams."
    end
    assert_equal :reply, MailboxMessage.new(@org, mail.to_s).process
    ticket.comments.order(:id).last
  end

  def api_ticket(ticket, user)
    token = user.api_tokens.create!(name: "t").plain_token
    get api_v1_ticket_url(ticket), headers: { "Authorization" => "Bearer #{token}" }
    response.parsed_body.dig("ticket", "timeline").filter_map { |event| event["comment"] }
  end

  test "a reply by mail keeps its own headers; staff open them under Mail details, nobody else sees them" do
    ticket = incoming
    reply = reply_to_ticket(ticket)
    assert_equal "Still jams.", reply.body
    assert_equal [ "ivan@example.com" ], reply.mail_headers["from"]
    assert_equal [ "boss@example.com" ], reply.mail_headers["cc"]
    assert_equal "Re: [Stopan ##{ticket.number}] Bread slicer jams", reply.mail_headers["subject"]
    assert_equal "r-1@example.com", reply.mail_headers["message_id"]
    in_app = ticket.add_comment(author: users(:agent), body: "On it.")
    assert_nil in_app.mail_headers

    sign_in users(:agent)
    get ticket_url(ticket)
    assert_select "details.mail-details", 1
    assert_select "#event-#{reply.event.id} .message__body > details.mail-details:last-child:not([open])" do
      assert_select "summary", "Mail details"
      assert_select ".mail-headers__list dd", "ivan@example.com"
      assert_select ".mail-headers__list dd", "boss@example.com"
      assert_select ".mail-headers__list dd", "Re: [Stopan ##{ticket.number}] Bread slicer jams"
      assert_select ".mail-headers__list dd.mail-headers__id", "r-1@example.com"
      assert_select ".mail-headers__list dt", text: "Reply-To", count: 0
    end
    comments = api_ticket(ticket, users(:agent))
    assert_equal "r-1@example.com", comments.find { it["id"] == reply.id }.dig("mail_headers", "message_id")
    assert_not comments.find { it["id"] == in_app.id }.key?("mail_headers")

    sign_in ticket.requester
    get ticket_url(ticket)
    assert_response :success
    assert_select "details.mail-details", 0
    assert_not_includes response.body, "r-1@example.com"
    assert api_ticket(ticket, ticket.requester).none? { it.key?("mail_headers") }

    ticket.share!(actor: users(:agent))
    get shared_ticket_url(ticket.share_token)
    assert_select "details.mail-details", 0
    assert_not_includes response.body, "r-1@example.com"
  end

  test "tickets without headers show no block" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select ".mail-headers", 0
  end
end
