require "test_helper"

# Only signed-in, active users get a WebSocket (specs/notifications.md).
class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  FakeWarden = Struct.new(:signed_in) do
    def user(_scope)
      signed_in
    end
  end

  test "connects a signed-in user" do
    connect env: { "warden" => FakeWarden.new(users(:anna)) }
    assert_equal users(:anna), connection.current_user
  end

  test "rejects visitors and deactivated users" do
    assert_reject_connection { connect env: { "warden" => FakeWarden.new(nil) } }
    assert_reject_connection { connect env: { "warden" => FakeWarden.new(users(:retired)) } }
    assert_reject_connection { connect }
  end
end
