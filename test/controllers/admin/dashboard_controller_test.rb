require "test_helper"

# The admin dashboard (specs/admin.md "Dashboard").
class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  def google!(organization, email, status: "connected")
    organization.create_mail_connection!(provider: "google", email: email, refresh_token: "refresh-#{organization.id}",
                                         connected_at: Time.current, status: status)
    organization.update!(mail_auth: "google")
  end

  test "Google accounts that need reconnecting are listed above the tiles, by organization name" do
    sign_in users(:admin)
    get admin_root_url
    assert_select ".mail-warning", 0

    google!(organizations(:acme), "support@acme.example")
    get admin_root_url
    assert_select ".mail-warning", 0

    organizations(:acme).mail_connection.update!(status: "needs_reconnect")
    google!(organizations(:globex), "help@globex.example", status: "needs_reconnect")
    get admin_root_url
    assert_select ".desk > .callout.mail-warning[role=status] + .stats"
    assert_select ".mail-warning li", 2
    assert_select ".mail-warning li:first-child" do
      assert_select "a[href=?]", admin_organization_path(organizations(:acme)), organizations(:acme).name
      assert_select "li", /the Google account support@acme\.example needs reconnecting/
    end
    assert_select ".mail-warning li:last-child a[href=?]", admin_organization_path(organizations(:globex))
  end

  test "a connection left over from Google after switching back to a password does not warn" do
    google!(organizations(:acme), "support@acme.example", status: "needs_reconnect")
    organizations(:acme).update!(mail_auth: "password")
    sign_in users(:admin)
    get admin_root_url
    assert_select ".mail-warning", 0
  end

  def with_build(version, committed_at)
    BuildInfo.instance_variable_set(:@current, BuildInfo.new(version, committed_at))
    yield
  ensure
    BuildInfo.instance_variable_set(:@current, nil)
  end

  test "the dashboard names the running version and its date in the reader's language" do
    sign_in users(:admin)
    get admin_root_url
    assert_select ".build-info", "Stopan, development version"

    with_build("v0.1.1-35-g98e4114", "2026-11-12T14:30:00+02:00") do
      get admin_root_url
      assert_select ".build-info", "Stopan v0.1.1-35-g98e4114, November 12, 2026"
      get admin_root_url, headers: { "Accept-Language" => "bg" }
      assert_select ".build-info", /Stopan v0\.1\.1-35-g98e4114, 12 ноември 2026/i
    end
    with_build("v0.2.0", nil) do
      get admin_root_url
      assert_select ".build-info", "Stopan v0.2.0"
    end
  end
end
