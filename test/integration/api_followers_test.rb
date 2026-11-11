require "test_helper"

# The People panel through the API (specs/followers.md "In the API").
class ApiFollowersTest < ActionDispatch::IntegrationTest
  setup do
    Api::V1::BaseController::RATE_LIMIT_STORE.clear
    @ticket = tickets(:printer) # Acme, requested by Anna, assigned to Maria Agent
  end

  def api(method, path, user:, params: nil)
    token = users(user).api_tokens.create!(name: "test").plain_token
    send(method, path, params: params, headers: { "Authorization" => "Bearer #{token}" }, as: (:json if params))
    response.parsed_body
  end

  test "staff add a colleague and a Cc, see both, and remove them" do
    body = api(:post, api_v1_ticket_followers_url(@ticket), user: :agent, params: { user_id: users(:agent_two).id })
    assert_response :created
    assert_equal [ "staff", users(:agent_two).id, users(:agent).id ],
                 [ body.dig("follower", "kind"), body.dig("follower", "user", "id"), body.dig("follower", "added_by", "id") ]

    body = api(:post, api_v1_ticket_followers_url(@ticket), user: :agent, params: { email: " Boris@Example.com" })
    assert_response :created
    assert_equal [ "cc", "boris@example.com" ], [ body.dig("follower", "kind"), body.dig("follower", "user", "email") ]

    body = api(:post, api_v1_ticket_followers_url(@ticket), user: :agent, params: { email: "petar@example.com" })
    assert_response :unprocessable_content
    assert_equal "invalid", body.dig("error", "code")
    assert_match "staff", body.dig("error", "message")
    api(:post, api_v1_ticket_followers_url(@ticket), user: :agent, params: { user_id: users(:agent_two).id })
    assert_response :unprocessable_content
    api(:post, api_v1_ticket_followers_url(@ticket), user: :agent, params: { user_id: users(:carl).id })
    assert_response :not_found
    api(:post, api_v1_ticket_followers_url(@ticket), user: :agent, params: { note: "x" })
    assert_response :bad_request

    @ticket.update_columns(mail_headers: { "cc" => [ "Ivan <ivan@example.net>" ] })
    ticket = api(:get, api_v1_ticket_url(@ticket), user: :agent)["ticket"]
    assert_equal [ [ "staff", users(:agent_two).id ], [ "cc", users(:boris).id ] ],
                 ticket["followers"].map { [ it["kind"], it.dig("user", "id") ] }
    assert ticket["followers"].all? { it["created_at"] && it["added_by"] }
    assert_equal [ "ivan@example.net" ], ticket["cc_suggestions"]

    cc = @ticket.ticket_followers.find_by(user: users(:boris))
    api(:delete, api_v1_ticket_follower_url(@ticket, cc), user: :agent)
    assert_response :no_content
    assert_not @ticket.cc?(users(:boris))
    event = @ticket.events.where(action: "follower_removed").last
    assert_equal [ users(:agent).id, "cc" ], [ event.actor_id, event.from_value ]
  end

  test "customers see the Cc names only; a Cc may leave, a requester manages nothing" do
    @ticket.follow!(users(:agent_two), actor: users(:agent))
    @ticket.add_cc!("boris@example.com", actor: users(:agent))
    cc = @ticket.ticket_followers.find_by(user: users(:boris))
    staff_row = @ticket.ticket_followers.find_by(user: users(:agent_two))

    ticket = api(:get, api_v1_ticket_url(@ticket), user: :anna)["ticket"]
    assert_equal [ { "id" => cc.id, "kind" => "cc",
                     "user" => { "id" => users(:boris).id, "name" => "Boris Requester", "role" => "requester" } } ],
                 ticket["followers"]
    assert_not ticket.key?("cc_suggestions")

    api(:post, api_v1_ticket_followers_url(@ticket), user: :anna, params: { email: "x@example.com" })
    assert_response :forbidden
    api(:delete, api_v1_ticket_follower_url(@ticket, cc), user: :anna)
    assert_response :forbidden
    api(:delete, api_v1_ticket_follower_url(@ticket, staff_row), user: :boris)
    assert_response :forbidden

    ticket = api(:get, api_v1_ticket_url(@ticket), user: :boris)["ticket"]
    assert_equal "boris@example.com", ticket["followers"].sole.dig("user", "email")
    api(:delete, api_v1_ticket_follower_url(@ticket, cc), user: :boris)
    assert_response :no_content
    assert_equal users(:boris).id, @ticket.events.where(action: "follower_removed").last.actor_id
    api(:get, api_v1_ticket_url(@ticket), user: :boris)
    assert_response :not_found
  end
end
