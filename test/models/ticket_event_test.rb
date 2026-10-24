require "test_helper"

class TicketEventTest < ActiveSupport::TestCase
  test "events are immutable" do
    event = ticket_events(:printer_created)
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "replied") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy }
  end

  test "visible_to hides internal events from requesters" do
    anna = TicketEvent.visible_to(users(:anna)).where(ticket: tickets(:printer)).pluck(:action)
    assert_equal %w[created replied status_changed].sort, anna.sort
    staff = TicketEvent.visible_to(users(:agent)).where(ticket: tickets(:printer)).count
    assert_equal 6, staff
  end

  test "action must be known" do
    assert TicketEvent.new(ticket: tickets(:printer), action: "exploded").invalid?
  end
end
