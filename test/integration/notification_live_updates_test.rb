require "test_helper"
require "turbo/broadcastable/test_helper"

# Live updates of the notification panel and page (specs/notifications.md
# "Live updates of the panel" and "... of the notifications page"): a
# content-free signal per user, and the panel or page fetched again over
# HTTP.
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

  test "a signal from a request carries its Turbo request id, others none" do
    signals = signals_to(users(:anna)) { tickets(:printer).add_comment(author: users(:agent), body: "Please try a new roll.") }
    assert_nil signals.first["request-id"]

    sign_in users(:anna)
    signals = signals_to(users(:anna)) do
      patch read_all_notifications_url, headers: { "X-Turbo-Request-Id" => "tab-request-1" }
    end
    assert_equal [ "tab-request-1" ], signals.map { |stream| stream["request-id"] }
  end

  test "the notifications page refreshes itself on the signal, keeping its scroll position" do
    sign_in users(:anna)
    get notifications_url
    assert_select "[data-notifications-page]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "turbo-cable-stream-source[channel=NotificationsChannel]"
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
