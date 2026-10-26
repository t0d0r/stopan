require "test_helper"

# Connections identify the signed-in, active user or nobody; shared ticket
# pages are public, so visitors connect too (specs/sharing.md).
class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  FakeWarden = Struct.new(:signed_in) do
    def user(_scope)
      signed_in
    end
  end

  test "identifies a signed-in user" do
    connect env: { "warden" => FakeWarden.new(users(:anna)) }
    assert_equal users(:anna), connection.current_user
  end

  test "visitors and deactivated users connect as nobody" do
    connect env: { "warden" => FakeWarden.new(users(:retired)) }
    assert_nil connection.current_user
    connect
    assert_nil connection.current_user
  end
end
