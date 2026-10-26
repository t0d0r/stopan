require "test_helper"
require "turbo/broadcastable/test_helper"

# Live updates of the admin pages (specs/admin.md).
class AdminLiveUpdatesTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  def admin_refreshes(&block)
    capture_turbo_stream_broadcasts(:admin) { perform_enqueued_jobs(&block) }.map { |signal| signal["action"] }
  end

  test "admin pages subscribe; other pages do not" do
    sign_in users(:admin)
    [ admin_root_url, admin_users_url, edit_admin_organization_url(organizations(:acme)) ].each do |url|
      get url
      assert_select "turbo-cable-stream-source[channel=AdminChannel][signed-stream-name=?]",
                    Turbo::StreamsChannel.signed_stream_name(:admin)
      assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    end

    get tickets_url
    assert_select "turbo-cable-stream-source[channel=AdminChannel]", 0
  end

  test "users, organizations, memberships and ticket events refresh the admin pages" do
    assert_equal [ "refresh" ], admin_refreshes { users(:anna).update!(name: "Anna P.") }
    assert_equal [ "refresh" ], admin_refreshes { organizations(:acme).update!(name: "Acme Bakery Ltd") }
    assert_equal [ "refresh" ], admin_refreshes { memberships(:anna_acme).destroy }
    ticket_change = admin_refreshes { tickets(:printer).apply_changes!({ priority: "urgent" }, actor: users(:agent)) }
    assert_equal [ "refresh" ], ticket_change
  end
end
