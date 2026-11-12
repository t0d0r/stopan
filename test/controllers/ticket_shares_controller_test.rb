require "test_helper"

# Creating, replacing and stopping share links (specs/sharing.md).
class TicketSharesControllerTest < ActionDispatch::IntegrationTest
  test "staff create a link with a password, replace it and stop sharing" do
    sign_in users(:agent)
    ticket = tickets(:vpn)
    post ticket_share_url(ticket), params: { share_password: "s3cret!" }
    assert_redirected_to ticket_url(ticket, anchor: "sharing")
    assert_equal "Share link created.", flash[:notice]
    first = ticket.reload.share_token
    assert ticket.share_password?

    get ticket_url(ticket)
    assert_select "#sharing input#share-url[readonly][value=?]", shared_ticket_url(first)
    assert_select "#sharing form[action=?] input[name=_method][value=delete]", ticket_share_path(ticket)
    assert_select ".timeline", /shared the ticket by link with a password/

    post ticket_share_url(ticket)
    assert_not_equal first, ticket.reload.share_token
    assert_not ticket.share_password?

    delete ticket_share_url(ticket)
    assert_equal "Sharing stopped.", flash[:notice]
    assert_not ticket.reload.shared?
  end

  test "the form offers the expiry choices and the panel shows the expiry" do
    sign_in users(:agent)
    ticket = tickets(:printer)
    get ticket_url(ticket)
    assert_select "#sharing select[name=share_expires_in] option", 4
    assert_select "#sharing select[name=share_expires_in] option[selected]", 0
    assert_select "#sharing label[for=share_expires_in_first]", "Expires"

    post ticket_share_url(ticket), params: { share_expires_in: "7" }
    assert_redirected_to ticket_url(ticket, anchor: "sharing")
    assert_in_delta 7.days.from_now, ticket.reload.share_expires_at, 5.seconds
    follow_redirect!
    assert_select "#sharing .sharing__expires", /Expires/
    assert_select ".timeline", /shared the ticket by link \(expires after 7 days\)/

    post ticket_share_url(ticket), params: { share_expires_in: "400" }
    assert_redirected_to ticket_url(ticket, anchor: "sharing")
    assert_match "Expiry", flash[:alert]
    assert_in_delta 7.days.from_now, ticket.reload.share_expires_at, 5.seconds
  end

  test "the panel and the admin list show how often the link was opened" do
    sign_in users(:admin)
    ticket = tickets(:printer)
    ticket.share!(actor: users(:agent))
    get ticket_url(ticket)
    assert_select "#sharing .sharing__views", "Not opened yet"

    ticket.count_share_view!
    get ticket_url(ticket)
    assert_select "#sharing .sharing__views", /Opened once, last/
    4.times { ticket.count_share_view! }
    get ticket_url(ticket)
    assert_select "#sharing .sharing__views", /Opened 5 times, last/
    get admin_root_url
    assert_select "##{ActionView::RecordIdentifier.dom_id(ticket, :shared)} .share-list__meta", /5 views/
  end

  test "an expired link leaves the panel, the lists and the admin list" do
    sign_in users(:admin)
    ticket = tickets(:printer)
    ticket.share!(actor: users(:agent), expires_in_days: 1)
    get admin_root_url
    assert_select "##{ActionView::RecordIdentifier.dom_id(ticket, :shared)} .share-list__meta", /expires/

    travel 2.days do
      get ticket_url(ticket)
      assert_select "#sharing #share-url", 0
      assert_select "#sharing select#share_expires_in_first"
      get admin_root_url
      assert_select "##{ActionView::RecordIdentifier.dom_id(ticket, :shared)}", 0

      ShareExpiry.run
      get ticket_url(ticket)
      assert_select ".timeline", /The share link expired/
    end
  end

  test "a too short password changes nothing" do
    sign_in users(:agent)
    post ticket_share_url(tickets(:vpn)), params: { share_password: "abc" }
    assert_match(/too short/, flash[:alert])
    assert_not tickets(:vpn).reload.shared?
  end

  test "requesters share their own tickets but not others'" do
    sign_in users(:anna)
    post ticket_share_url(tickets(:printer))
    assert tickets(:printer).reload.shared?

    get ticket_url(tickets(:printer))
    assert_select "#sharing"
    assert_select ".timeline", text: /shared the ticket/, count: 0

    post ticket_share_url(tickets(:vpn))
    assert_response :not_found
  end

  test "a requester who left the organization cannot share" do
    memberships(:anna_acme).destroy
    sign_in users(:anna)
    post ticket_share_url(tickets(:printer))
    assert_redirected_to no_organization_url
    assert_not tickets(:printer).reload.shared?
  end

  test "ticket lists mark shared tickets" do
    tickets(:printer).share!(actor: users(:agent))
    sign_in users(:agent)
    get tickets_url(view: "all")
    assert_select "#ticket_#{tickets(:printer).id} .ticket-link svg[aria-label='Shared by link']"
    assert_select "#ticket_#{tickets(:vpn).id} .ticket-link svg", 0
  end

  test "the admin dashboard lists shared tickets and can stop them" do
    tickets(:printer).share!(actor: users(:agent), password: "s3cret!")
    sign_in users(:admin)
    get admin_root_url
    assert_select "#shared_ticket_#{tickets(:printer).id}", /With password/
    assert_select "#shared_ticket_#{tickets(:printer).id} form[action=?]", ticket_share_path(tickets(:printer))

    delete ticket_share_url(tickets(:printer)), headers: { "Referer" => admin_root_url }
    assert_redirected_to admin_root_url
    assert_not tickets(:printer).reload.shared?
  end
end
