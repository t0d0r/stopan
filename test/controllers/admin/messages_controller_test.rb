require "test_helper"
require "turbo/broadcastable/test_helper"

# Messages from administrators in the recipients' notifications
# (specs/notifications.md "Messages from administrators").
class Admin::MessagesControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup { sign_in users(:admin) }

  test "a message to one user lands in their notifications, live" do
    get new_admin_message_url(user_id: users(:anna).id, return_to: "/admin/users")
    assert_select "select[name='admin_message[recipients]'] option[selected][value=?][data-count='1']", "user:#{users(:anna).id}"

    signals = capture_turbo_stream_broadcasts([ users(:anna), :notifications ]) do
      perform_enqueued_jobs do
        post admin_messages_url, params: { return_to: "/admin/users",
                                           admin_message: { recipients: "user:#{users(:anna).id}", text: "Planned outage tonight.\nBack at 22:00." } }
      end
    end
    assert_redirected_to admin_users_url
    assert_equal "Message sent to 1 user.", flash[:notice]
    assert_equal [ "notifications_refresh" ], signals.map { |s| s["action"] }

    note = Notification.last
    assert_equal [ users(:anna), users(:admin), "message", nil ], [ note.user, note.actor, note.kind, note.ticket ]

    sign_in users(:anna)
    get panel_notifications_url
    assert_select ".notify-item", /#{users(:admin).display_name} sent you a message/
    assert_select ".notify-item__ticket", "Planned outage tonight."
    get notification_url(note)
    assert_response :success
    assert_select ".ticket-text", /Planned outage tonight\.\s*Back at 22:00\./
    assert note.reload.read_at
  end

  test "roles, organizations and everyone reach active users, never the sender" do
    users(:boris).update!(deactivated_at: Time.current)
    post admin_messages_url, params: { admin_message: { recipients: "role:requester", text: "Hi requesters" } }
    assert_equal User.active.where(role: "requester").pluck(:id).sort, Notification.where(message: "Hi requesters").pluck(:user_id).sort

    post admin_messages_url, params: { admin_message: { recipients: "organization:#{organizations(:acme).id}", text: "Hi Acme" } }
    assert_not Notification.where(message: "Hi Acme", user: users(:boris)).exists?
    assert Notification.where(message: "Hi Acme", user: users(:anna)).exists?

    post admin_messages_url, params: { admin_message: { recipients: "all", text: "Hi all" } }
    assert_not Notification.where(message: "Hi all", user: users(:admin)).exists?
    assert_equal User.active.where.not(id: users(:admin).id).count, Notification.where(message: "Hi all").count
  end

  test "empty text, no recipients and foreign return paths are refused" do
    post admin_messages_url, params: { admin_message: { recipients: "user:#{users(:anna).id}", text: "" } }
    assert_response :unprocessable_content
    post admin_messages_url, params: { admin_message: { recipients: "role:nobody", text: "Hi" } }
    assert_response :unprocessable_content
    post admin_messages_url, params: { return_to: "https://evil.example/x", admin_message: { recipients: "all", text: "Hi" } }
    assert_redirected_to admin_users_url
  end

  test "only admins send messages; others cannot read someone else's" do
    sign_in users(:agent)
    post admin_messages_url, params: { admin_message: { recipients: "all", text: "Hi" } }
    assert_redirected_to root_url
    note = Notification.create!(user: users(:anna), actor: users(:admin), kind: "message", message: "Private")
    get notification_url(note)
    assert_response :not_found
  end

  test "the users list and the organization page link to the form" do
    get admin_users_url
    assert_select "#user_#{users(:anna).id} a.icon-action[href^=?][href*=?]", new_admin_message_path, "user_id=#{users(:anna).id}"
    get admin_organization_url(organizations(:acme))
    assert_select "a[href^=?][href*=?]", new_admin_message_path, "organization_id=#{organizations(:acme).id}"
  end
end
