require "test_helper"
require "turbo/broadcastable/test_helper"

# The public page of a shared ticket (specs/sharing.md).
class SharedTicketsControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper
  setup { SharedTicketsController::RATE_LIMIT_STORE.clear }

  def share(ticket = tickets(:printer), password: nil)
    ticket.share!(actor: users(:agent), password: password)
    ticket.share_token
  end

  test "an open link shows the public part of the ticket without sign-in" do
    token = share
    get shared_ticket_url(token)
    assert_response :success
    assert_select "h1", tickets(:printer).subject
    assert_select ".pill--status", "In progress"
    assert_includes response.body, comments(:printer_reply).body
    assert_not_includes response.body, "STAFF-ONLY"
    assert_not_includes response.body, users(:anna).email
    assert_not_includes response.body, organizations(:acme).name
    assert_select ".pill--priority", 0
    assert_select ".timeline__item--internal", 0
    assert_select "main form", 0
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "unknown, replaced and stopped links are not available" do
    old = share
    current = share
    get shared_ticket_url(old)
    assert_response :not_found
    assert_select "h1", "Link not available"

    get shared_ticket_url(current)
    assert_response :success
    tickets(:printer).unshare!(actor: users(:agent))
    get shared_ticket_url(current)
    assert_response :not_found

    get shared_ticket_url("x" * 32)
    assert_response :not_found
  end

  test "a password link asks for the password once per session" do
    token = share(password: "s3cret!")
    get shared_ticket_url(token)
    assert_select "form#unlock_form"
    assert_not_includes response.body, comments(:printer_reply).body

    post unlock_shared_ticket_url(token), params: { password: "wrong-one" }
    assert_response :unprocessable_content
    assert_select "form#unlock_form"

    post unlock_shared_ticket_url(token), params: { password: "s3cret!" }
    assert_redirected_to shared_ticket_url(token)
    follow_redirect!
    assert_includes response.body, comments(:printer_reply).body

    tickets(:printer).share!(actor: users(:agent), password: "other-pass")
    get shared_ticket_url(tickets(:printer).share_token)
    assert_select "form#unlock_form"
  end

  test "password attempts are rate limited per token" do
    token = share(password: "s3cret!")
    10.times { post unlock_shared_ticket_url(token), params: { password: "wrong-one" } }
    post unlock_shared_ticket_url(token), params: { password: "s3cret!" }
    assert_response :too_many_requests
  end

  test "files of the ticket and public replies download; internal and other tickets' files do not" do
    ticket = tickets(:printer)
    ticket.files.attach(upload("hello.txt"))
    public_reply = ticket.add_comment(author: users(:agent), body: "See the file", files: [ upload ])
    note = ticket.add_comment(author: users(:agent), body: "Internal file", internal: true, files: [ upload ])
    other = tickets(:vpn).add_comment(author: users(:agent), body: "Other ticket", files: [ upload ])
    token = share(ticket)

    get shared_ticket_url(token)
    assert_select "a[href=?]", shared_ticket_file_path(token, ticket.files.first)
    assert_select "a[href=?]", shared_ticket_file_path(token, public_reply.files.first)

    get shared_ticket_file_url(token, ticket.files.first)
    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"])
    get shared_ticket_file_url(token, public_reply.files.first)
    assert_response :success
    get shared_ticket_file_url(token, note.files.first)
    assert_response :not_found
    get shared_ticket_file_url(token, other.files.first)
    assert_response :not_found
  end

  test "files of a locked link redirect to the password form" do
    ticket = tickets(:printer)
    ticket.files.attach(upload)
    token = share(ticket, password: "s3cret!")
    get shared_ticket_file_url(token, ticket.files.first)
    assert_redirected_to shared_ticket_url(token)
    get shared_ticket_file_preview_url(token, ticket.files.first)
    assert_redirected_to shared_ticket_url(token)
  end

  test "shared previews: public files inline, internal files not" do
    ticket = tickets(:printer)
    public_reply = ticket.add_comment(author: users(:agent), body: "See the file", files: [ upload ])
    note = ticket.add_comment(author: users(:agent), body: "Internal file", internal: true, files: [ upload ])
    token = share(ticket)

    get shared_ticket_url(token)
    assert_select "a.file-link[data-preview-url=?]", shared_ticket_file_preview_path(token, public_reply.files.first)
    get shared_ticket_file_preview_url(token, public_reply.files.first)
    assert_response :success
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
    assert_equal "default-src 'none'; sandbox", response.headers["Content-Security-Policy"]
    get shared_ticket_file_preview_url(token, note.files.first)
    assert_response :not_found
  end

  test "an open shared page subscribes to a stream named by a hash of the token" do
    token = share
    get shared_ticket_url(token)
    signed = Turbo::StreamsChannel.signed_stream_name(tickets(:printer).share_stream)
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel'][signed-stream-name=?]", signed
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]", 1
    assert_not_includes Turbo::StreamsChannel.verified_stream_name(signed), token
  end

  test "a locked page does not subscribe" do
    get shared_ticket_url(share(password: "s3cret!"))
    assert_select "turbo-cable-stream-source", 0
  end

  test "public changes refresh the shared page; internal ones do not" do
    ticket = tickets(:printer)
    share(ticket)
    stream = ticket.share_stream

    refreshes = lambda do |&block|
      capture_turbo_stream_broadcasts(stream) { perform_enqueued_jobs(&block) }.map { |signal| signal["action"] }
    end
    assert_equal [ "refresh" ], refreshes.call { ticket.add_comment(author: users(:agent), body: "Public answer") }
    assert_empty refreshes.call { ticket.add_comment(author: users(:agent), body: "SECRET", internal: true) }
    assert_empty refreshes.call { ticket.apply_changes!({ priority: "urgent" }, actor: users(:agent)) }
    assert_equal [ "refresh" ], refreshes.call { ticket.apply_changes!({ status: "resolved" }, actor: users(:agent)) }
    assert_equal [ "refresh" ], refreshes.call { ticket.unshare!(actor: users(:agent)) }
  end

  test "replacing the link tells the old page" do
    ticket = tickets(:printer)
    share(ticket)
    old_stream = ticket.share_stream
    signals = capture_turbo_stream_broadcasts(old_stream) { perform_enqueued_jobs { share(ticket) } }
    assert_equal [ "refresh" ], signals.map { |signal| signal["action"] }
  end
end
