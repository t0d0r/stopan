require "test_helper"

# In-app notifications follow the email rules (specs/notifications.md
# "Notification panel").
class NotificationTest < ActiveSupport::TestCase
  test "a reply with a status change stores one notification per recipient, not for the actor" do
    ticket = tickets(:printer)
    ticket.update_columns(assignee_id: users(:agent_two).id)

    assert_difference("Notification.count", 2) do
      ticket.add_comment(author: users(:agent), body: "Please try a new roll.", status: "pending")
    end
    anna = users(:anna).notifications.sole
    assert_equal [ "replied", "pending", users(:agent) ], [ anna.kind, anna.status, anna.actor ]
    assert_equal "replied", anna.event.action
    assert_empty users(:agent).notifications
  end

  test "internal notes notify only staff, and requesters never see staff kinds" do
    ticket = tickets(:printer)
    ticket.update_columns(assignee_id: users(:agent_two).id)
    ticket.add_comment(author: users(:agent), body: "SECRET", internal: true)

    assert_equal [ "noted" ], users(:agent_two).notifications.pluck(:kind)
    assert_empty users(:anna).notifications

    note = Notification.create!(user: users(:anna), ticket: ticket, kind: "noted")
    assert_not_includes Notification.visible_to(users(:anna)), note
  end

  test "notifications of tickets the user can no longer see are hidden" do
    tickets(:printer).add_comment(author: users(:agent), body: "Any news?")
    assert_equal 1, Notification.visible_to(users(:anna)).count

    memberships(:anna_acme).destroy
    assert_equal 0, Notification.visible_to(users(:anna)).count
  end

  test "each user keeps the newest 200" do
    keep = Notification::KEEP
    3.times { Notification.create!(user: users(:anna), ticket: tickets(:printer), kind: "replied") }
    assert_operator users(:anna).notifications.count, :<=, keep
    Notification.insert_all(Array.new(keep) { { user_id: users(:anna).id, ticket_id: tickets(:printer).id, kind: "replied",
                                                       created_at: 1.day.ago, updated_at: 1.day.ago } })
    newest = Notification.create!(user: users(:anna), ticket: tickets(:printer), kind: "replied")
    assert_equal keep, users(:anna).notifications.count
    assert_includes users(:anna).notifications, newest
  end
end
