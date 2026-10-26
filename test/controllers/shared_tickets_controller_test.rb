require "test_helper"

# The public page of a shared ticket (specs/sharing.md).
class SharedTicketsControllerTest < ActionDispatch::IntegrationTest
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
  end
end
