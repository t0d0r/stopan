require "test_helper"

# The board's hover preview (specs/board.md "Preview on hover").
class TicketPreviewsTest < ActionDispatch::IntegrationTest
  setup { @ticket = tickets(:printer) }

  test "staff get a fragment with the start of the request, the latest message and the counts" do
    @ticket.update_columns(description: "First line\nSecond <b>line</b> " + ("x" * 700))
    @ticket.add_comment(author: users(:agent), body: "Public answer")
    @ticket.add_comment(author: users(:agent), body: "<script>alert(1)</script> note " + ("y" * 400), internal: true)
    replies = @ticket.comments.where(internal: false).count
    sign_in users(:agent)

    get preview_ticket_url(@ticket)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_no_match(/<html|<body|menubar/, response.body)
    assert_select ".card-preview__number", @ticket.reference
    assert_select ".card-preview__subject", @ticket.subject
    assert_select ".pill--status"
    assert_select "time.card-preview__date[datetime=?]", @ticket.created_at.iso8601, I18n.l(@ticket.created_at, format: :short)

    @ticket.update_columns(mail_headers: { "date" => "2026-11-01T08:00:00+02:00" })
    get preview_ticket_url(@ticket)
    # The mail's own clock time, as the ticket page shows it.
    assert_select "time.card-preview__date", "01 Nov 08:00"
    get preview_ticket_url(@ticket), headers: { "Accept-Language" => "bg" }
    assert_select "time.card-preview__date", /01 ноем/i
    @ticket.update_columns(mail_headers: { "date" => "not a date" })
    get preview_ticket_url(@ticket)
    assert_select "time.card-preview__date[datetime=?]", @ticket.created_at.iso8601
    text = css_select(".card-preview__text").first.text
    assert text.start_with?("First line\nSecond <b>line</b>")
    assert_equal 600, text.length
    assert text.end_with?("...")
    assert_select ".card-preview__text b", 0
    assert_select ".card-preview__latest--internal .card-preview__by", /Latest internal note by\s+#{users(:agent).display_name}/
    assert_select ".card-preview__latest script", 0
    assert_includes css_select(".card-preview__latest .card-preview__text").first.text, "<script>alert(1)</script> note"
    assert_equal 300, css_select(".card-preview__latest .card-preview__text").first.text.length
    notes = @ticket.comments.where(internal: true).count
    assert_select ".card-preview__counts", /#{replies} repl(y|ies) · #{notes} notes? · no files/
  end

  test "a ticket without messages has no latest part" do
    ticket = Ticket.create!(subject: "Fresh", description: "Just opened", requester: users(:anna), organization: organizations(:acme),
                            actor: users(:anna))
    sign_in users(:agent)
    get preview_ticket_url(ticket)
    assert_select ".card-preview__latest", 0
    assert_select ".card-preview__counts", /no replies · no notes · no files/
  end

  test "requesters, strangers and tickets outside the viewer's organizations get nothing" do
    sign_in users(:anna)
    get preview_ticket_url(@ticket)
    assert_response :forbidden

    other = Ticket.where.not(organization_id: users(:agent).memberships.select(:organization_id)).first
    if other
      sign_in users(:agent)
      get preview_ticket_url(other)
      assert_response :not_found
    end

    sign_out :user
    get preview_ticket_url(@ticket)
    assert_redirected_to new_user_session_url
  end

  test "a preview marks no notification read" do
    @ticket.add_comment(author: users(:anna), body: "Any news?")
    unread = Notification.where(user: users(:agent), ticket: @ticket, read_at: nil).count
    sign_in users(:agent)
    get preview_ticket_url(@ticket)
    assert_equal unread, Notification.where(user: users(:agent), ticket: @ticket, read_at: nil).count
  end

  test "the card carries the address of its preview" do
    sign_in users(:agent)
    get board_url
    assert_select "[data-board-card][data-preview-url=?]", preview_ticket_path(@ticket)
    assert_select "#card-preview[role=tooltip][hidden]"
  end
end
