require "test_helper"

# The staff "new tickets" opt-in and the remembered language
# (specs/notifications.md).
class NotificationsControllerTest < ActionDispatch::IntegrationTest
  test "staff turn new ticket emails on and off without their password" do
    sign_in users(:agent)
    get edit_user_registration_url
    assert_select "form#notifications input[type=checkbox][name=?]", "user[notify_new_tickets]"

    patch user_notifications_url, params: { user: { notify_new_tickets: "1", role: "admin", email: "x@example.com" } }
    assert_redirected_to edit_user_registration_path
    users(:agent).reload
    assert users(:agent).notify_new_tickets?
    assert_equal "agent", users(:agent).role
    assert_equal "maria@example.com", users(:agent).email

    patch user_notifications_url, params: { user: { notify_new_tickets: "0" } }
    assert_not users(:agent).reload.notify_new_tickets?
  end

  test "requesters have no such setting" do
    sign_in users(:anna)
    get edit_user_registration_url
    assert_select "form#notifications", count: 0

    patch user_notifications_url, params: { user: { notify_new_tickets: "1" } }
    assert_response :forbidden
    assert_not users(:anna).reload.notify_new_tickets?
  end

  test "signed-out users are sent to sign in" do
    patch user_notifications_url, params: { user: { notify_new_tickets: "1" } }
    assert_redirected_to new_user_session_url
  end

  test "the browser language of a signed-in user is remembered for emails" do
    sign_in users(:anna)
    get tickets_url, headers: { "Accept-Language" => "bg-BG,bg;q=0.9" }
    assert_equal "bg", users(:anna).reload.locale

    get tickets_url
    assert_equal "bg", users(:anna).reload.locale, "no header keeps the stored language"

    get tickets_url, headers: { "Accept-Language" => "de-DE" }
    assert_equal "bg", users(:anna).reload.locale, "an unsupported language keeps it too"

    get tickets_url, headers: { "Accept-Language" => "en-US" }
    assert_equal "en", users(:anna).reload.locale
  end
end
