require "test_helper"

# Who may hear the ticket lists' refresh signals (specs/queues.md).
class TicketListsChannelTest < ActionCable::Channel::TestCase
  def signed(*streamables)
    Turbo::StreamsChannel.signed_stream_name(streamables)
  end

  test "staff hear the queue, requesters their own list" do
    stub_connection current_user: users(:agent)
    subscribe signed_stream_name: signed(:queue, :staff)
    assert subscription.confirmed?

    stub_connection current_user: users(:anna)
    subscribe signed_stream_name: signed(users(:anna), :tickets)
    assert subscription.confirmed?
  end

  test "requesters cannot hear the queue or another requester's list, visitors nothing" do
    stub_connection current_user: users(:anna)
    subscribe signed_stream_name: signed(:queue, :staff)
    assert subscription.rejected?
    subscribe signed_stream_name: signed(users(:boris), :tickets)
    assert subscription.rejected?

    stub_connection current_user: nil
    subscribe signed_stream_name: signed(:queue, :staff)
    assert subscription.rejected?
  end

  test "requesters do not hear organization lists (specs/roles.md)" do
    stub_connection current_user: users(:anna)
    subscribe signed_stream_name: signed(organizations(:acme), :tickets)
    assert subscription.rejected?
    subscribe signed_stream_name: signed(organizations(:globex), :tickets)
    assert subscription.rejected?
  end
end
