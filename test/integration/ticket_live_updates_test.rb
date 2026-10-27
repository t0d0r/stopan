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

  def list_refreshes(*stream, &block)
    capture_turbo_stream_broadcasts(stream) { perform_enqueued_jobs(&block) }.map { |signal| signal["action"] }
  end

  test "ticket lists subscribe to the queue or the requester's own list" do
    sign_in users(:agent)
    get tickets_url
    assert_select "turbo-cable-stream-source[channel=TicketListsChannel][signed-stream-name=?]",
                  Turbo::StreamsChannel.signed_stream_name([ :queue, :staff ])
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"

    sign_in users(:anna)
    get tickets_url
    assert_select "turbo-cable-stream-source[channel=TicketListsChannel][signed-stream-name=?]",
                  Turbo::StreamsChannel.signed_stream_name([ users(:anna), :tickets ])
  end

  test "the queue hears every change, a requester's list only public changes of their tickets" do
    ticket = tickets(:printer)
    assert_equal [ "refresh" ], list_refreshes(:queue, :staff) { ticket.apply_changes!({ priority: "urgent" }, actor: users(:agent)) }
    assert_empty list_refreshes(users(:anna), :tickets) { ticket.apply_changes!({ priority: "low" }, actor: users(:agent)) }
    assert_equal [ "refresh" ], list_refreshes(users(:anna), :tickets) { ticket.add_comment(author: users(:agent), body: "Hi") }
    assert_empty list_refreshes(users(:boris), :tickets) { ticket.add_comment(author: users(:agent), body: "Again") }
    # No organization-wide list any more: requesters see only their own tickets (specs/roles.md).
    assert_empty list_refreshes(organizations(:acme), :tickets) { ticket.add_comment(author: users(:agent), body: "Org") }

    created = list_refreshes(:queue, :staff) do
      Ticket.create!(subject: "New one", description: "Text", requester: users(:anna), organization: organizations(:acme),
                     actor: users(:anna))
    end
    assert_equal [ "refresh" ], created
  end
end
