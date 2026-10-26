require "test_helper"

# Ticket share links (specs/sharing.md).
class TicketShareTest < ActiveSupport::TestCase
  test "sharing makes a new token each time and records internal events" do
    ticket = tickets(:printer)
    updated_at = ticket.updated_at

    assert ticket.share!(actor: users(:agent))
    first = ticket.reload.share_token
    assert_equal 32, first.length
    assert_not ticket.share_password?
    assert ticket.share!(actor: users(:agent), password: "s3cret!")
    assert_not_equal first, ticket.reload.share_token
    assert ticket.authenticate_share_password("s3cret!")
    assert_equal updated_at.to_i, ticket.updated_at.to_i

    events = ticket.events.where(action: "shared").order(:id)
    assert_equal [ nil, "password" ], events.pluck(:to_value)
    assert events.all?(&:internal?)
  end

  test "passwords must be 6 to 72 characters" do
    ticket = tickets(:printer)
    assert_not ticket.share!(actor: users(:agent), password: "short")
    assert_not ticket.share!(actor: users(:agent), password: "x" * 73)
    assert_not ticket.reload.shared?
    assert_includes ticket.errors.full_messages.first, "Share password"
  end

  test "unsharing clears the link once and sends no email" do
    ticket = tickets(:printer)
    ticket.share!(actor: users(:anna), password: "s3cret!")
    ticket.unshare!(actor: users(:agent))
    ticket.unshare!(actor: users(:agent))

    ticket.reload
    assert_nil ticket.share_token
    assert_nil ticket.share_password_digest
    assert_nil ticket.shared_at
    assert_equal 1, ticket.events.where(action: "unshared").count
    assert_empty TicketNotifier.new(ticket, ticket.events.where(action: %w[shared unshared]).to_a).notifications
  end
end
