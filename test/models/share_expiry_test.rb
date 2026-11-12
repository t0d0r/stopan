require "test_helper"
require "turbo/broadcastable/test_helper"

# Share links that stop on their own (specs/sharing.md "Expiry").
class ShareExpiryTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  include ActiveJob::TestHelper

  setup { @ticket = tickets(:printer) }

  test "a link takes one of the fixed periods and records it" do
    freeze_time do
      assert @ticket.share!(actor: users(:agent), expires_in_days: "7")
      assert_equal 7.days.from_now, @ticket.reload.share_expires_at
      assert_equal "7", @ticket.events.where(action: "shared").last.detail
    end
    assert @ticket.shared?
    assert_includes Ticket.shared, @ticket
  end

  test "no period means the link never expires" do
    assert @ticket.share!(actor: users(:agent), expires_in_days: "")
    assert_nil @ticket.reload.share_expires_at
    assert_nil @ticket.events.where(action: "shared").last.detail
  end

  test "another period is refused and nothing changes" do
    [ "2", "0", "-1", "365", "soon" ].each do |days|
      assert_not @ticket.share!(actor: users(:agent), expires_in_days: days), days
    end
    assert_nil @ticket.reload.share_token
    assert_equal 0, @ticket.events.where(action: "shared").count
  end

  test "replacing a link sets the expiry anew" do
    @ticket.share!(actor: users(:agent), expires_in_days: 1)
    @ticket.share!(actor: users(:agent))
    assert_nil @ticket.reload.share_expires_at
  end

  test "an expired link is not shared before the clean-up runs" do
    @ticket.share!(actor: users(:agent), expires_in_days: 1)
    travel 1.day + 1.second do
      assert_not @ticket.reload.shared?
      assert_not_includes Ticket.shared, @ticket
      assert_includes Ticket.share_expired, @ticket
      assert @ticket.share_token.present?
    end
  end

  test "the clean-up clears expired links once, with one event and a refresh" do
    @ticket.share!(actor: users(:agent), password: "s3cret!", expires_in_days: 1)
    endless = tickets(:vpn)
    endless.share!(actor: users(:agent))
    later = tickets(:old_question)
    later.share!(actor: users(:agent), expires_in_days: 30)
    stream = @ticket.share_stream

    travel 2.days do
      signals = capture_turbo_stream_broadcasts(stream) { perform_enqueued_jobs { assert_equal 1, ShareExpiry.run } }
      assert_equal [ "refresh" ], signals.map { |signal| signal["action"] }
      @ticket.reload
      assert_nil @ticket.share_token
      assert_nil @ticket.share_password_digest
      assert_nil @ticket.shared_at
      assert_nil @ticket.share_expires_at
      event = @ticket.events.where(action: "share_expired").sole
      assert event.internal?
      assert_nil event.actor

      assert_equal 0, ShareExpiry.run
      assert endless.reload.shared?
      assert later.reload.shared?
    end
  end

  test "an automatic customer link has no expiry and replaces an expired one" do
    ticket = tickets(:printer)
    ticket.update_columns(source: "email")
    ticket.share!(actor: users(:agent), expires_in_days: 1)
    old = ticket.share_token

    travel 2.days do
      ticket.reload.share_for_customer!(ticket.requester)
      ticket.reload
      assert_not_equal old, ticket.share_token
      assert_nil ticket.share_expires_at
      assert_equal :email_password, ticket.share_link_for(ticket.requester)
    end
  end
end
