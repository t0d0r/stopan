require "test_helper"

# The JSON API with personal tokens (specs/api.md).
class ApiTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { Api::V1::BaseController::RATE_LIMIT_STORE.clear }

  def token_for(user, **attributes)
    user.api_tokens.create!(name: "test", **attributes).plain_token
  end

  def auth(token) = { "Authorization" => "Bearer #{token}" }

  def api(method, path, user: nil, token: nil, params: nil, as: :json)
    token ||= token_for(users(user))
    send(method, path, params: params, headers: auth(token), as: (as if params))
    response.parsed_body
  end

  test "no, wrong, expired, revoked or deactivated tokens are 401; the token is stored only as a digest" do
    get api_v1_me_url
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")
    assert_equal 'Bearer realm="Stopan"', response.headers["WWW-Authenticate"]

    get api_v1_me_url, headers: auth("stopan_wrong")
    assert_response :unauthorized

    token = token_for(users(:anna))
    assert_not ApiToken.where(token_digest: token).exists?
    assert ApiToken.exists?(token_digest: Digest::SHA256.hexdigest(token))
    get api_v1_me_url(token: token)
    assert_response :unauthorized, "never from the query string"

    get api_v1_me_url, headers: auth(token)
    assert_response :success
    assert_equal users(:anna).email, response.parsed_body.dig("user", "email")
    assert ApiToken.find_by(token_digest: Digest::SHA256.hexdigest(token)).last_used_at

    users(:anna).update!(deactivated_at: Time.current)
    get api_v1_me_url, headers: auth(token)
    assert_response :unauthorized

    expired = token_for(users(:boris))
    ApiToken.last.update!(expires_at: 1.minute.ago)
    get api_v1_me_url, headers: auth(expired)
    assert_response :unauthorized

    revoked = token_for(users(:boris))
    delete api_v1_token_url(ApiToken.last), headers: auth(revoked)
    assert_response :no_content
    get api_v1_me_url, headers: auth(revoked)
    assert_response :unauthorized
  end

  test "a read-only token reads but changes nothing" do
    token = token_for(users(:agent), read_only: true)
    get api_v1_ticket_url(tickets(:printer)), headers: auth(token)
    assert_response :success
    assert_no_difference "Comment.count" do
      post api_v1_ticket_comments_url(tickets(:printer)), params: { comment: { body: "Hi" } }, headers: auth(token), as: :json
    end
    assert_response :forbidden
    assert_equal "read_only", response.parsed_body.dig("error", "code")
    delete api_v1_token_url(ApiToken.last), headers: auth(token)
    assert_response :forbidden
  end

  test "a requester's token sees only their own tickets, never internal content" do
    body = api(:get, api_v1_tickets_url(view: "all"), user: :anna)
    assert_equal [ 1001, 1004 ], body["tickets"].map { |ticket| ticket["number"] }.sort

    body = api(:get, api_v1_ticket_url(tickets(:printer)), user: :anna)
    timeline = body.dig("ticket", "timeline")
    assert timeline.none? { |event| event["internal"] }
    assert_not_includes response.body, "STAFF-ONLY"
    assert_not body["ticket"].key?("mail_headers")

    api(:get, api_v1_ticket_url(tickets(:email_account)), user: :anna)
    assert_response :not_found
    api(:get, api_v1_ticket_url(tickets(:vpn)), user: :anna)
    assert_response :not_found
    api(:patch, api_v1_ticket_url(tickets(:printer)), user: :anna, params: { ticket: { status: "done" } })
    assert_response :forbidden
    api(:get, api_v1_users_url, user: :anna)
    assert_response :forbidden
  end

  test "a requester opens a ticket and replies; internal flags become public replies" do
    token = token_for(users(:anna))
    assert_difference -> { Ticket.count } => 1 do
      perform_enqueued_jobs do
        post api_v1_tickets_url, params: { ticket: { subject: "Oven", description: "Too hot", priority: "urgent" } },
                                 headers: auth(token), as: :json
      end
    end
    assert_response :created
    ticket = Ticket.order(:id).last
    assert_equal [ users(:anna), "normal", "created" ], [ ticket.requester, ticket.priority, ticket.events.first.action ]
    assert Notification.exists?(ticket: ticket), "the same notifications as from the page"

    post api_v1_ticket_comments_url(ticket), params: { comment: { body: "More heat", internal: true } }, headers: auth(token), as: :json
    assert_response :created
    assert_not response.parsed_body.dig("comment", "internal")

    post resolve_api_v1_ticket_url(ticket), headers: auth(token)
    assert_equal "done", response.parsed_body.dig("ticket", "status")
  end

  test "staff work tickets through the API like on the page" do
    token = token_for(users(:agent))
    ticket = tickets(:printer)
    patch api_v1_ticket_url(ticket), params: { ticket: { priority: "high", assignee_id: users(:agent).id } }, headers: auth(token), as: :json
    assert_response :success
    assert_equal [ "high", users(:agent).id ], [ ticket.reload.priority, ticket.assignee_id ]

    post api_v1_ticket_comments_url(ticket), params: { comment: { body: "Checked", internal: true } }, headers: auth(token), as: :json
    assert response.parsed_body.dig("comment", "internal")
    post api_v1_ticket_comments_url(ticket), params: { comment: { body: "Fixed", status: "pending" } }, headers: auth(token), as: :json
    assert_equal "pending", ticket.reload.status

    comment = ticket.comments.last
    patch api_v1_ticket_comment_url(ticket, comment), params: { comment: { body: "Fixed now", markdown: true } }, headers: auth(token), as: :json
    assert_equal [ "Fixed now", true ], [ comment.reload.body, comment.markdown? ]

    patch api_v1_ticket_description_url(ticket), params: { ticket: { subject: "Printer prints blank" } }, headers: auth(token), as: :json
    assert_equal "Printer prints blank", ticket.reload.subject
    body = api(:get, api_v1_ticket_revisions_url(ticket), token: token)
    assert body["revisions"].any? { |revision| revision["record"] == "description" }

    post api_v1_ticket_share_url(ticket), params: { password: "secret12" }, headers: auth(token), as: :json
    assert_response :created
    assert_equal shared_ticket_url(ticket.reload.share_token), response.parsed_body["share_url"]
    delete api_v1_ticket_share_url(ticket), headers: auth(token)
    assert_not ticket.reload.shared?

    api(:get, api_v1_ticket_url(tickets(:vpn)), token: token)
    assert_response :success
    api(:get, api_v1_reports_url(period: "7d"), token: token)
    assert response.parsed_body.dig("report", "tiles").key?("open")
    api(:get, api_v1_users_url, token: token)
    assert_response :forbidden
  end

  test "files go up as multipart and come down through the API" do
    token = token_for(users(:anna))
    post api_v1_tickets_url, headers: auth(token),
                             params: { ticket: { subject: "Photo", description: "See file",
                                                 files: [ fixture_file_upload("dot.png", "image/png") ] } }
    assert_response :created
    file = response.parsed_body.dig("ticket", "files", 0)
    assert_equal "dot.png", file["filename"]
    get file["url"], headers: auth(token)
    assert_response :success
    assert_equal "image/png", response.media_type

    get file["url"], headers: auth(token_for(users(:boris)))
    assert_response :not_found
  end

  test "notifications and the user's own settings" do
    token = token_for(users(:anna))
    perform_enqueued_jobs { tickets(:printer).add_comment(author: users(:agent), body: "News") }
    body = api(:get, api_v1_notifications_url, token: token)
    assert body["unread_count"].positive?
    post read_all_api_v1_notifications_url, headers: auth(token)
    assert_equal 0, api(:get, api_v1_notifications_url, token: token)["unread_count"]

    patch api_v1_me_url, params: { user: { language: "bg", notify_new_tickets: true } }, headers: auth(token), as: :json
    assert_equal [ "bg", false ], [ users(:anna).reload.language, users(:anna).notify_new_tickets ]
    get api_v1_ticket_url(999_999), headers: auth(token)
    assert_equal "Не е намерено.", response.parsed_body.dig("error", "message")
  end

  test "administrators manage users, organizations, settings and stages; secrets never come back" do
    token = token_for(users(:admin))
    post api_v1_users_url, params: { user: { name: "Eve", email: "eve@example.com", password: "s3cret-pass-1",
                                             role: "requester", organization_ids: [ organizations(:acme).id ] } },
                           headers: auth(token), as: :json
    assert_response :created
    eve = User.find_by!(email: "eve@example.com")
    assert eve.member_of?(organizations(:acme))
    patch api_v1_user_url(users(:admin)), params: { user: { role: "requester" } }, headers: auth(token), as: :json
    assert users(:admin).reload.admin?, "no change of one's own role"
    delete api_v1_user_url(eve), headers: auth(token)
    assert_response :no_content

    patch api_v1_organization_url(organizations(:acme)), headers: auth(token), as: :json,
                                                         params: { organization: { notes: "Bakery", imap_password: "mail-secret" } }
    assert_response :success
    assert_equal true, response.parsed_body.dig("organization", "imap_password_set")
    assert_not_includes response.body, "mail-secret"

    patch api_v1_settings_url, params: { settings: { timeline_order: "newest_first", deepl_api_key: "key-secret:fx" } },
                               headers: auth(token), as: :json
    assert_equal [ "newest_first", true ], response.parsed_body["settings"].values_at("timeline_order", "deepl_api_key_set")
    assert_not_includes response.body, "key-secret"
    patch api_v1_settings_url, params: { settings: { timeline_order: "sideways" } }, headers: auth(token), as: :json
    assert_response :unprocessable_content
    assert response.parsed_body.dig("error", "details", "timeline_order")

    post api_v1_stages_url, params: { stage: { status: "open", name: "Waiting for parts", color: "blue" } }, headers: auth(token), as: :json
    assert_response :created
    post api_v1_organization_memberships_url(organizations(:globex)), params: { membership: { user_id: users(:anna).id } },
                                                                      headers: auth(token), as: :json
    assert_response :created
    post api_v1_messages_url, params: { message: { recipients: "user:#{users(:anna).id}", text: "Hello" } }, headers: auth(token), as: :json
    assert_response :created
  end

  test "the account page makes tokens, shows them once and revokes them" do
    sign_in users(:boris)
    get edit_user_registration_url
    assert_select "#api-tokens form#new-api-token-form input[name='api_token[read_only]'][type=checkbox]"
    post api_tokens_url, params: { api_token: { name: "Monitoring", read_only: "1", expires_in_days: "30" } }
    token = users(:boris).api_tokens.last
    assert token.read_only?
    assert_in_delta 30.days.from_now, token.expires_at, 5
    follow_redirect!
    shown = css_select("#new-api-token").first["value"]
    assert_equal token.token_digest, Digest::SHA256.hexdigest(shown)
    assert_select ".api-tokens__list", /Monitoring.*Read-only/m

    get edit_user_registration_url
    assert_select "#new-api-token", 0, "shown only once"
    delete api_token_url(token)
    assert_not ApiToken.exists?(token.id)
    delete api_token_url(ApiToken.create!(user: users(:anna), name: "theirs"))
    assert_response :not_found
  end
end
