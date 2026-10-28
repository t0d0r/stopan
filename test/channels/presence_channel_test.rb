require "test_helper"

# Each open page of a signed-in user counts as online (specs/presence.md).
class PresenceChannelTest < ActionCable::Channel::TestCase
  setup { Presence.reset }
  teardown { Presence.reset }

  def signed(*streamables)
    Turbo::StreamsChannel.signed_stream_name(streamables)
  end

  test "staff join on the staff stream, with the ticket they see, until they leave" do
    stub_connection current_user: users(:agent)
    subscribe ticket: tickets(:printer).number, signed_stream_name: signed(:presence, :staff)
    assert subscription.confirmed?
    assert_has_stream Turbo::StreamsChannel.verified_stream_name(signed(:presence, :staff))
    assert_equal [ users(:agent).id ], Presence.viewer_ids(tickets(:printer))

    unsubscribe
    assert_empty Presence.user_ids
  end

  test "a requester joins on their own stream, and a ticket they cannot see is not recorded" do
    stub_connection current_user: users(:carl)
    subscribe ticket: tickets(:printer).number, signed_stream_name: signed(users(:carl), :presence)
    assert subscription.confirmed?
    assert_equal [ users(:carl).id ], Presence.user_ids
    assert_empty Presence.viewer_ids(tickets(:printer))
  end

  test "another stream or no sign-in is rejected and not counted" do
    stub_connection current_user: users(:anna)
    subscribe signed_stream_name: signed(:presence, :staff)
    assert subscription.rejected?
    subscribe signed_stream_name: signed(users(:boris), :presence)
    assert subscription.rejected?

    stub_connection current_user: nil
    subscribe signed_stream_name: signed(:presence, :staff)
    assert subscription.rejected?
    assert_empty Presence.user_ids
  end
end
