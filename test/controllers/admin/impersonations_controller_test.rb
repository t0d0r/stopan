require "test_helper"

# Admins acting as another user (specs/admin.md "Impersonation").
class Admin::ImpersonationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "an admin signs in as a requester, sees the banner and comes back" do
    users(:anna).update_columns(current_sign_in_at: 1.day.ago.change(usec: 0))
    signed_in_at = users(:anna).current_sign_in_at
    assert_difference -> { Impersonation.count } do
      post admin_user_impersonation_url(users(:anna))
    end
    assert_redirected_to root_url
    follow_redirect!
    follow_redirect! while response.redirect?
    assert_select ".impersonation-banner", /You are signed in as Anna Requester \(Requester\) by impersonation/
    assert_select ".menubar__user-name", users(:anna).display_name
    assert_equal signed_in_at, users(:anna).reload.current_sign_in_at

    record = Impersonation.last
    assert_equal [ users(:admin), users(:anna), nil ], [ record.admin, record.user, record.ended_at ]

    get admin_users_url
    assert_redirected_to root_url

    delete impersonation_url
    assert_redirected_to edit_admin_user_url(users(:anna))
    assert record.reload.ended_at
    follow_redirect!
    assert_select ".impersonation-banner", 0
    assert_select ".menubar__user-name", users(:admin).display_name
    assert_select ".impersonation-panel td", /#{users(:admin).display_name}/
  end

  test "admins, deactivated users and oneself cannot be impersonated" do
    other_admin = User.create!(email: "admin2@example.com", password: "password-123", role: "admin", name: "Second Admin")
    users(:boris).update!(deactivated_at: Time.current)
    [ other_admin, users(:boris), users(:admin) ].each do |user|
      post admin_user_impersonation_url(user)
      assert_response :forbidden
    end
    assert_equal 0, Impersonation.count
  end

  test "non-admins cannot start one" do
    sign_in users(:agent)
    post admin_user_impersonation_url(users(:anna))
    assert_redirected_to root_url
    assert_equal 0, Impersonation.count
  end

  test "the account page is locked while impersonating" do
    post admin_user_impersonation_url(users(:agent))
    get edit_user_registration_url
    assert_redirected_to root_url
    put user_registration_url, params: { user: { email: "taken@example.com", current_password: "x" } }
    assert_redirected_to root_url
    patch user_notifications_url, params: { user: { notify_new_tickets: "1" } }
    assert_response :forbidden
    assert_not_equal "taken@example.com", users(:agent).reload.email
  end

  test "the impersonation ends when the admin loses the right" do
    post admin_user_impersonation_url(users(:anna))
    users(:admin).update_columns(role: "agent")
    get tickets_url
    assert_redirected_to new_user_session_url
    assert_equal "The impersonation ended. Please sign in again.", flash[:alert]
  end

  test "the user's admin page offers it with a confirm dialog" do
    get edit_admin_user_url(users(:anna))
    assert_select "form[action=?][data-confirm] button", admin_user_impersonation_path(users(:anna)), "Sign in as Anna Requester"
    get edit_admin_user_url(users(:admin))
    assert_select "form[action=?]", admin_user_impersonation_path(users(:admin)), 0
  end
end
