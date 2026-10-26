require "test_helper"
require "turbo/broadcastable/test_helper"

# Live updates of the ticket page (specs/timeline.md).
class TicketLiveUpdatesTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  def refreshes(audience, &block)
    capture_turbo_stream_broadcasts([ tickets(:printer), :page, audience ]) { perform_enqueued_jobs(&block) }
      .map { |signal| signal["action"] }
  end

  test "staff and requester pages subscribe to their own stream with scroll kept" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select "turbo-cable-stream-source[channel=TicketsChannel][data-ticket='1001'][signed-stream-name=?]",
                  Turbo::StreamsChannel.signed_stream_name([ tickets(:printer), :page, :staff ])
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "[data-live-notice][hidden]"

    sign_in users(:anna)
    get ticket_url(tickets(:printer))
    assert_select "turbo-cable-stream-source[channel=TicketsChannel][signed-stream-name=?]",
                  Turbo::StreamsChannel.signed_stream_name([ tickets(:printer), :page, :public ])
  end

  test "public changes reach both streams, internal ones only staff" do
    ticket = tickets(:printer)
    assert_equal [ "refresh" ], refreshes(:public) { ticket.add_comment(author: users(:agent), body: "Public") }
    assert_empty refreshes(:public) { ticket.add_comment(author: users(:agent), body: "SECRET", internal: true) }
    assert_equal [ "refresh" ], refreshes(:staff) { ticket.add_comment(author: users(:agent), body: "SECRET", internal: true) }
    assert_empty refreshes(:public) { ticket.apply_changes!({ priority: "urgent" }, actor: users(:agent)) }
    assert_equal [ "refresh" ], refreshes(:staff) { ticket.apply_changes!({ priority: "low" }, actor: users(:agent)) }
  end
end
