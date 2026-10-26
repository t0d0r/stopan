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
    assert_response :not_found
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
