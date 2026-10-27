require "test_helper"

# Who may hear a shared page's signals, and each subscription as one
# viewer (specs/sharing.md "Who is viewing now").
class SharedTicketChannelTest < ActionCable::Channel::TestCase
  setup do
    ShareViewers::COUNTS.clear
    @ticket = tickets(:printer)
    @ticket.share!(actor: users(:agent), password: nil)
  end

  teardown { ShareViewers::COUNTS.clear }

  def signed(ticket = @ticket)
    Turbo::StreamsChannel.signed_stream_name(ticket.share_stream)
  end

  test "a visitor with the current link subscribes and counts until leaving" do
    stub_connection current_user: nil
    subscribe ticket: 1001, signed_stream_name: signed
    assert subscription.confirmed?
    assert_has_stream Turbo::StreamsChannel.verified_stream_name(signed)
    assert_equal 1, ShareViewers.count(@ticket)

    unsubscribe
    assert_equal 0, ShareViewers.count(@ticket)
  end

  test "an old link, another ticket or an unshared ticket is rejected and not counted" do
    stub_connection current_user: nil
    old = signed
    @ticket.share!(actor: users(:agent), password: nil)
    subscribe ticket: 1001, signed_stream_name: old
    assert subscription.rejected?

    subscribe ticket: 1003, signed_stream_name: signed
    assert subscription.rejected?

    current = signed
    @ticket.unshare!(actor: users(:agent))
    subscribe ticket: 1001, signed_stream_name: current
    assert subscription.rejected?
    assert_empty ShareViewers::COUNTS
  end
end
