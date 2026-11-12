require "test_helper"

# The requester puts colleagues of the organization in Cc
# (specs/followers.md "The requester adds colleagues").
class RequesterCcTest < ActionDispatch::IntegrationTest
  setup do
    Api::V1::BaseController::RATE_LIMIT_STORE.clear
    @ticket = tickets(:printer) # Acme, requested by Anna; Boris is a member, Carl is not
  end

  def api(method, path, user:, params: nil)
    token = users(user).api_tokens.create!(name: "test").plain_token
    send(method, path, params: params, headers: { "Authorization" => "Bearer #{token}" }, as: (:json if params))
    response.parsed_body
  end

  test "the requester sees the members to add, without addresses, and adds one" do
    assert_equal [ users(:boris) ], @ticket.cc_candidates.to_a
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "#followers form[action=?] select[name=user_id]", ticket_followers_path(@ticket) do
      assert_select "option[value=?]", users(:boris).id.to_s, text: "Boris Requester"
      assert_select "option", 2
    end
    assert_select "#followers input[name=email]", 0
    assert_no_match "boris@example.com", response.body

    post ticket_followers_url(@ticket), params: { user_id: users(:boris).id }
    assert_redirected_to ticket_url(@ticket, anchor: "followers")
    assert_equal "Boris Requester is now in Cc.", flash[:notice]
    follower = @ticket.ticket_followers.find_by(user: users(:boris))
    assert_equal users(:anna), follower.added_by
    event = @ticket.events.where(action: "follower_added").last
    assert_equal [ users(:anna).id, "cc", true ], [ event.actor_id, event.from_value, event.internal ]
    assert_empty @ticket.cc_candidates

    get ticket_url(@ticket)
    assert_select "#followers form[action=?] button", ticket_follower_path(@ticket, follower), text: /Remove/
    assert_select "#followers select[name=user_id]", 0
    delete ticket_follower_url(@ticket, follower)
    assert_redirected_to ticket_url(@ticket, anchor: "followers")
    assert_not @ticket.cc?(users(:boris))
  end

  test "an address, an outsider, staff, a deactivated member and a second add are refused" do
    sign_in users(:anna)
    post ticket_followers_url(@ticket), params: { email: "new@example.com" }
    assert_response :forbidden
    assert_not User.exists?(email: "new@example.com")
    sign_in users(:anna)
    [ users(:carl), users(:agent_two), users(:anna) ].each do |user|
      post ticket_followers_url(@ticket), params: { user_id: user.id }
      assert_response :not_found
      sign_in users(:anna)
    end
    users(:boris).update!(deactivated_at: Time.current)
    post ticket_followers_url(@ticket), params: { user_id: users(:boris).id }
    assert_response :not_found
    users(:boris).update!(deactivated_at: nil)
    sign_in users(:anna)
    post ticket_followers_url(@ticket), params: { user_id: users(:boris).id }
    post ticket_followers_url(@ticket), params: { user_id: users(:boris).id }
    assert_response :not_found
    assert_equal 1, @ticket.ticket_followers.count
  end

  test "the requester removes only people they added; a person in Cc adds nobody" do
    by_staff = @ticket.add_cc!("boris@example.com", actor: users(:agent))
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "#followers form", 0
    delete ticket_follower_url(@ticket, by_staff)
    assert_response :forbidden
    assert @ticket.cc?(users(:boris))

    Membership.create!(user: users(:carl), organization: organizations(:acme))
    sign_in users(:boris)
    get ticket_url(@ticket)
    assert_select "#followers select[name=user_id]", 0
    post ticket_followers_url(@ticket), params: { user_id: users(:carl).id }
    assert_response :forbidden
  end

  test "the API follows: candidates for the requester, adding and removing" do
    ticket = api(:get, api_v1_ticket_url(@ticket), user: :anna)["ticket"]
    assert_equal [ { "id" => users(:boris).id, "name" => "Boris Requester" } ], ticket["cc_candidates"]
    assert_not api(:get, api_v1_ticket_url(@ticket), user: :agent)["ticket"].key?("cc_candidates")

    api(:post, api_v1_ticket_followers_url(@ticket), user: :anna, params: { email: "boris@example.com" })
    assert_response :forbidden
    api(:post, api_v1_ticket_followers_url(@ticket), user: :anna, params: { user_id: users(:carl).id })
    assert_response :not_found
    body = api(:post, api_v1_ticket_followers_url(@ticket), user: :anna, params: { user_id: users(:boris).id })
    assert_response :created
    assert_equal [ "cc", users(:boris).id ], [ body.dig("follower", "kind"), body.dig("follower", "user", "id") ]
    assert_not body["follower"].key?("added_by")

    api(:delete, api_v1_ticket_follower_url(@ticket, body.dig("follower", "id")), user: :anna)
    assert_response :no_content
    assert_not @ticket.cc?(users(:boris))
  end
end
