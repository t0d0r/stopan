require "test_helper"
require "turbo/broadcastable/test_helper"

# Who has Stopan open now (specs/presence.md).
class PresenceTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup { Presence.reset }
  teardown { Presence.reset }

  test "a user is online while one of their pages is open" do
    Presence.join("a", users(:agent))
    Presence.join("b", users(:agent), tickets(:printer))
    Presence.join("c", users(:anna), tickets(:printer))
    assert_equal [ users(:agent).id, users(:anna).id ].sort, Presence.user_ids.sort
    assert_equal [ users(:agent).id, users(:anna).id ].sort, Presence.viewer_ids(tickets(:printer)).sort
    assert_empty Presence.viewer_ids(tickets(:vpn))

    Presence.leave("b")
    assert_includes Presence.user_ids, users(:agent).id
    assert_equal [ users(:anna).id ], Presence.viewer_ids(tickets(:printer))

    Presence.leave("a")
    Presence.leave("a")
    assert_equal [ users(:anna).id ], Presence.user_ids
  end

  test "staff hear the staff stream, a requester only their own" do
    assert_equal [ :presence, :staff ], Presence.stream(users(:agent))
    assert_equal [ users(:anna), :presence ], Presence.stream(users(:anna))
  end

  test "signals staff only when the set of pages changes, without names" do
    Presence.join("a", users(:agent))
    broadcasts = capture_turbo_stream_broadcasts([ :presence, :staff ]) { assert Presence.announce }
    assert_equal [ "presence_refresh" ], broadcasts.map { |stream| stream["action"] }
    assert_no_match(/#{users(:agent).name}/, broadcasts.first.to_html)

    assert_empty capture_turbo_stream_broadcasts([ :presence, :staff ]) { assert_not Presence.announce }

    # A page refresh leaves and joins again: the same set, no signal.
    Presence.leave("a")
    Presence.join("a2", users(:agent))
    assert_empty capture_turbo_stream_broadcasts([ :presence, :staff ]) { assert_not Presence.announce }

    Presence.join("b", users(:agent), tickets(:printer))
    assert_equal 1, capture_turbo_stream_broadcasts([ :presence, :staff ]) { assert Presence.announce }.size
  end
end
