require "test_helper"

# The People panel (specs/followers.md "The panel", "Routes").
class TicketFollowersControllerTest < ActionDispatch::IntegrationTest
  setup { @ticket = tickets(:printer) }

  test "staff follow, add a colleague and a Cc, and remove them" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "section#followers.side-panel" do
      assert_select "form[action=?] input[name=user_id][value=?]", ticket_followers_path(@ticket), users(:agent).id.to_s
      assert_select "select[name=user_id] option[value=?]", users(:agent_two).id.to_s
      assert_select "input[type=email][name=email]"
    end

    post ticket_followers_url(@ticket), params: { user_id: users(:agent).id }
    assert_redirected_to ticket_url(@ticket, anchor: "followers")
    post ticket_followers_url(@ticket), params: { user_id: users(:agent_two).id }
    post ticket_followers_url(@ticket), params: { email: "boris@example.com" }
    assert_equal "Boris Requester is now in Cc.", flash[:notice] if users(:boris).display_name == "Boris Requester"
    assert_equal [ users(:agent), users(:agent_two), users(:boris) ].map(&:id).sort, @ticket.followers.pluck(:id).sort

    get ticket_url(@ticket)
    assert_select "#followers form[action=?] button", ticket_follower_path(@ticket, @ticket.ticket_followers.find_by(user: users(:agent))),
                  "Stop following"
    assert_select "#followers .followers__email", "boris@example.com"
    assert_select ".timeline__text", "Maria Agent follows the ticket"
    assert_select ".timeline__text", /Maria Agent added .+ to Cc/

    delete ticket_follower_url(@ticket, @ticket.ticket_followers.find_by(user: users(:boris)))
    assert_not @ticket.cc?(users(:boris))
  end

  test "a refused address comes back as an alert" do
    sign_in users(:agent)
    post ticket_followers_url(@ticket), params: { email: "petar@example.com" }
    assert_match "staff", flash[:alert]
    post ticket_followers_url(@ticket), params: { user_id: users(:carl).id }
    assert_response :not_found
  end

  test "requesters may not manage; staff outside the organization get a 404" do
    @ticket.add_cc!("boris@example.com", actor: users(:agent))
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "#followers" do
      assert_select ".followers__item", text: /#{users(:boris).display_name}/
      assert_select ".followers__email", 0
      assert_select "form", 0
      assert_select "h3", text: "Following", count: 0
    end
    post ticket_followers_url(@ticket), params: { email: "x@example.com" }
    assert_response :forbidden
    delete ticket_follower_url(@ticket, @ticket.ticket_followers.first)
    assert_response :forbidden
    assert @ticket.cc?(users(:boris))

    memberships(:agent_acme).destroy
    sign_in users(:agent)
    post ticket_followers_url(@ticket), params: { user_id: users(:agent).id }
    assert_response :not_found
  end

  test "a customer sees no panel without anyone in Cc" do
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "#followers", 0
  end

  test "staff see the mail's To and Cc as suggestions" do
    @ticket.update_columns(mail_headers: { "cc" => [ "Ivan <ivan@example.net>" ] })
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#followers form[action=?] input[name=email][value=?]", ticket_followers_path(@ticket), "ivan@example.net"
  end
end
