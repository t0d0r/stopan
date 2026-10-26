require "test_helper"
require "turbo/broadcastable/test_helper"

# Live updates of the notification panel (specs/notifications.md "Live
# updates of the panel"): a content-free signal per user, and the panel
# fetched again over HTTP.
class NotificationLiveUpdatesTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  def signals_to(user, &block)
    capture_turbo_stream_broadcasts([ user, :notifications ]) { perform_enqueued_jobs(&block) }
  end

  test "signed-in pages subscribe to their own notification stream" do
    sign_in users(:anna)
    get tickets_url
    signed = Turbo::StreamsChannel.signed_stream_name([ users(:anna), :notifications ])
    assert_select "turbo-cable-stream-source[channel=NotificationsChannel][signed-stream-name=?]", signed
    assert_select "details#notifications[data-notifications][data-panel-url=?]", panel_notifications_path
  end

  test "a new notification sends a signal without content to the recipient only" do
    signals = signals_to(users(:anna)) do
      tickets(:printer).add_comment(author: users(:agent), body: "Please try a new roll.")
    end
    assert_equal [ "notifications_refresh" ], signals.map { |stream| stream["action"] }
    assert_empty signals.first.at("template").inner_html.strip
    assert_empty signals_to(users(:agent)) { tickets(:printer).add_comment(author: users(:agent), body: "Again") }
  end

  test "reading notifications signals the user's other pages, once" do
    tickets(:printer).add_comment(author: users(:agent), body: "Please try a new roll.")
    sign_in users(:anna)

    assert_equal 1, signals_to(users(:anna)) { get ticket_url(tickets(:printer)) }.size
    assert_empty signals_to(users(:anna)) { get ticket_url(tickets(:printer)) }
  end

  test "the panel endpoint renders the bell and panel for the signed-in user" do
    tickets(:printer).add_comment(author: users(:agent), body: "Please try a new roll.")
    sign_in users(:anna)
    get panel_notifications_url
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_not_includes response.body, "<html"
    assert_select ".menubar", 0
    assert_select "details#notifications .notify__count", "1"
    assert_not_includes response.body, "Please try a new roll."
  end

  test "the panel endpoint needs sign-in" do
    get panel_notifications_url
    assert_redirected_to new_user_session_url
  end
end
