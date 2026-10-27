require "test_helper"
require "turbo/broadcastable/test_helper"

# Live count of open shared pages per link (specs/sharing.md "Who is
# viewing now").
class ShareViewersTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    ShareViewers::COUNTS.clear
    @ticket = tickets(:printer)
    @ticket.share!(actor: users(:agent), password: nil)
  end

  teardown { ShareViewers::COUNTS.clear }

  test "counts open pages per link and never below zero" do
    digest = @ticket.share_digest
    2.times { ShareViewers.join(@ticket, digest) }
    assert_equal 2, ShareViewers.count(@ticket)

    3.times { ShareViewers.leave(@ticket, digest) }
    assert_equal 0, ShareViewers.count(@ticket)
    assert_not ShareViewers::COUNTS.key?(digest)
  end

  test "a new link starts from zero and an unshared ticket has no viewers" do
    ShareViewers.join(@ticket, @ticket.share_digest)
    @ticket.share!(actor: users(:agent), password: nil)
    assert_equal 0, ShareViewers.count(@ticket)

    ShareViewers.join(@ticket, @ticket.share_digest)
    @ticket.unshare!(actor: users(:agent))
    assert_equal 0, ShareViewers.count(@ticket)
  end

  test "changes send only the count to the shared pages and the ticket pages" do
    digest = @ticket.share_digest
    share = capture_turbo_stream_broadcasts([ @ticket, :share, digest ]) do
      staff = capture_turbo_stream_broadcasts([ @ticket, :page, :staff ]) do
        public = capture_turbo_stream_broadcasts([ @ticket, :page, :public ]) { ShareViewers.join(@ticket, digest) }
        assert_equal [ "1" ], public.map { |stream| stream["count"] }
      end
      assert_equal [ "share_viewers" ], staff.map { |stream| stream["action"] }
    end
    assert_equal [ "1" ], share.map { |stream| stream["count"] }
    assert_empty share.first.at("template").inner_html.strip
  end

  test "an old link's pages do not change the ticket pages' count" do
    old = @ticket.share_digest
    ShareViewers.join(@ticket, old)
    @ticket.share!(actor: users(:agent), password: nil)

    staff = capture_turbo_stream_broadcasts([ @ticket, :page, :staff ]) { ShareViewers.leave(@ticket, old) }
    assert_empty staff
  end
end
