require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "finds a user by username or email, ignoring case" do
    admin = users(:admin)
    assert_equal admin, User.find_for_database_authentication(email: "admin")
    assert_equal admin, User.find_for_database_authentication(email: "admin@example.com")
    assert_equal admin, User.find_for_database_authentication(email: "ADMIN")
    assert_nil User.find_for_database_authentication(email: "nobody")
  end

  test "display_name prefers the name, then the username, then the email" do
    assert_equal "Ada Admin", users(:admin).display_name
    assert_equal "ada", User.new(email: "x@example.com", username: "ada", name: " ").display_name
    assert_equal "x@example.com", User.new(email: "x@example.com", username: "").display_name
  end

  test "roles" do
    assert users(:admin).staff?
    assert users(:agent).staff?
    assert_not users(:anna).staff?
    assert users(:anna).requester?
    assert_equal "requester", User.new.role
    assert_not User.new(email: "x@example.com", password: "password", role: "boss").valid?
  end

  test "deactivated users cannot sign in" do
    assert_not users(:retired).active_for_authentication?
    assert_equal :deactivated, users(:retired).inactive_message
    assert users(:agent).active_for_authentication?
  end

  test "membership" do
    assert users(:anna).member_of?(organizations(:acme))
    assert_not users(:anna).member_of?(organizations(:globex))
    assert_not users(:anna).member_of?(nil)
  end

  test "releasing assigned tickets unassigns unsolved ones with an event" do
    maria = users(:agent)
    assert_difference -> { TicketEvent.where(action: "assignee_changed").count }, 1 do
      maria.release_assigned_tickets!(users(:admin))
    end
    printer = tickets(:printer).reload
    assert_nil printer.assignee
    event = printer.events.last
    assert_equal users(:admin), event.actor
    assert_equal maria.id.to_s, event.from_value
    assert event.internal?
  end

  test "users with ticket history cannot be deleted" do
    assert users(:anna).ticket_history?
    assert_not users(:anna).destroy
    assert_not users(:drifter).ticket_history?
    assert users(:drifter).destroy
  end

  test "ids_with_ticket_history matches ticket_history? for every user" do
    ids = User.ids_with_ticket_history(User.ids)
    User.find_each { |user| assert_equal user.ticket_history?, ids.include?(user.id), user.username }
  end
end
