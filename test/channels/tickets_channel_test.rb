require "test_helper"

# Who may hear a ticket page's refresh signals (specs/timeline.md "Live
# updates of the ticket page").
class TicketsChannelTest < ActionCable::Channel::TestCase
  def signed(ticket, audience)
    Turbo::StreamsChannel.signed_stream_name([ ticket, :page, audience ])
  end

  test "staff hear the staff stream, requesters the public stream of their own ticket" do
    stub_connection current_user: users(:agent)
    subscribe ticket: 1001, signed_stream_name: signed(tickets(:printer), :staff)
    assert subscription.confirmed?

    stub_connection current_user: users(:anna)
    subscribe ticket: 1001, signed_stream_name: signed(tickets(:printer), :public)
    assert subscription.confirmed?
  end

  test "requesters cannot hear the staff stream, other tickets or anything after losing access" do
    stub_connection current_user: users(:anna)
    subscribe ticket: 1001, signed_stream_name: signed(tickets(:printer), :staff)
    assert subscription.rejected?

    subscribe ticket: 1003, signed_stream_name: signed(tickets(:vpn), :public)
    assert subscription.rejected?

    subscribe ticket: 1001, signed_stream_name: signed(tickets(:vpn), :public)
    assert subscription.rejected?

    memberships(:anna_acme).destroy
    subscribe ticket: 1001, signed_stream_name: signed(tickets(:printer), :public)
    assert subscription.rejected?
  end

  test "visitors are rejected" do
    stub_connection current_user: nil
    subscribe ticket: 1001, signed_stream_name: signed(tickets(:printer), :public)
    assert subscription.rejected?
  end
end
