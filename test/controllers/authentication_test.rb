require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "signs in with username or email" do
    post user_session_url, params: { user: { email: "anna", password: "password" } }
    assert_redirected_to root_url
  end

  test "deactivated users cannot sign in" do
    post user_session_url, params: { user: { email: "retired@example.com", password: "password" } }
    assert_redirected_to new_user_session_url
    follow_redirect!
    assert_match "deactivated", response.body
  end

  test "a signed-in user who is deactivated is signed out" do
    sign_in users(:agent)
    get tickets_url
    assert_response :success
    users(:agent).update_column(:deactivated_at, Time.current)
    get tickets_url
    assert_redirected_to new_user_session_url
  end

  test "ten failed attempts lock the account" do
    10.times { post user_session_url, params: { user: { email: "anna", password: "wrong" } } }
    assert users(:anna).reload.access_locked?
    post user_session_url, params: { user: { email: "anna", password: "password" } }
    assert_response :unprocessable_content
    get tickets_url
    assert_redirected_to new_user_session_url
  end

  test "pages carry a content security policy" do
    get new_user_session_url
    policy = response.headers["Content-Security-Policy"]
    assert_match "script-src 'self'", policy
    assert_match "frame-ancestors 'none'", policy
    assert_match "object-src 'none'", policy
  end
end
