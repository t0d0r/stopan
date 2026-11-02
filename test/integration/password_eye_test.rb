require "test_helper"

# The eye on password fields (specs/ui.md "Password fields").
class PasswordEyeTest < ActionDispatch::IntegrationTest
  def assert_eye(field_id)
    assert_select "[data-password-field]:has(input[type=password]##{field_id})" do
      assert_select "button[type=button][data-password-toggle][hidden][aria-pressed=false][aria-controls=?]", field_id
      assert_select "button[aria-label='Show password'][data-hide-label='Hide password']"
    end
  end

  test "sign-in has the eye" do
    get new_user_session_url
    assert_eye "user_password"
  end

  test "resetting the password has the eye on both fields" do
    token = users(:anna).send(:set_reset_password_token)
    get edit_user_password_url(reset_password_token: token)
    assert_eye "user_password"
    assert_eye "user_password_confirmation"
  end

  test "the own account page has the eye on every password field" do
    sign_in users(:agent)
    get edit_user_registration_url
    %w[user_password user_password_confirmation user_current_password].each { |id| assert_eye id }
  end
end
