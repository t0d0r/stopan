require "test_helper"

# The menu bar bell, the panel and the notifications page.
class NotificationPanelTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer)
    @ticket.add_comment(author: users(:agent), body: "Please try a new roll.", status: "pending")
    @notification = users(:anna).notifications.sole
  end

  test "the bell shows the unread count and the panel the newest notifications" do
    sign_in users(:anna)
    get tickets_url
    assert_select ".menubar summary.notify__button[aria-label='Notifications, 1 unread'] .notify__count", "1"
    assert_select ".notify__panel a.notify-item.is-unread[href=?]", notification_path(@notification) do
      assert_select ".notify-item__sentence", /Maria Agent replied and set the status to Pending/
      assert_select ".notify-item__ticket", /#1001/
    end
    assert_not_includes response.body[/<details class="notify".*?<\/details>/m], "Please try a new roll."
  end

  test "opening a notification marks it read and jumps to the event" do
    sign_in users(:anna)
    get notification_url(@notification)
    assert_redirected_to ticket_url(@ticket, anchor: "event-#{@notification.event_id}")
    assert_not @notification.reload.unread?

    follow_redirect!
    assert_select ".notify__count", 0
    assert_select "summary.notify__button[aria-label='Notifications, none unread']"
  end

  test "opening the ticket marks its notifications read" do
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_not @notification.reload.unread?
  end

  test "other users' notifications are not found" do
    sign_in users(:boris)
    get notification_url(@notification)
    assert_response :not_found
  end

  test "mark all as read and the notifications page" do
    sign_in users(:anna)
    get notifications_url
    assert_select ".notify__list--page a.notify-item", 1
    patch read_all_notifications_url, headers: { "Referer" => notifications_url }
    assert_redirected_to notifications_url
    assert_equal 0, users(:anna).notifications.unread.count
  end

  test "signed-out pages have no bell" do
    get new_user_session_url
    assert_select ".notify", 0
  end
end
