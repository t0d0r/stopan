require "test_helper"

# Only the signed-in owner may hear a notification stream
# (specs/notifications.md).
class NotificationsChannelTest < ActionCable::Channel::TestCase
  def signed(user)
    Turbo::StreamsChannel.signed_stream_name([ user, :notifications ])
  end

  test "the owner subscribes to their own stream" do
    stub_connection current_user: users(:anna)
    subscribe signed_stream_name: signed(users(:anna))
    assert subscription.confirmed?
    assert_has_stream Turbo::StreamsChannel.verified_stream_name(signed(users(:anna)))
  end

  test "another user's stream, a visitor and a forged name are rejected" do
    stub_connection current_user: users(:boris)
    subscribe signed_stream_name: signed(users(:anna))
    assert subscription.rejected?

    stub_connection current_user: nil
    subscribe signed_stream_name: signed(users(:anna))
    assert subscription.rejected?

    stub_connection current_user: users(:anna)
    subscribe signed_stream_name: "forged"
    assert subscription.rejected?
  end
end
