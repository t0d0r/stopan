require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def with_registration(open)
    previous = Rails.configuration.x.registration_open
    Rails.configuration.x.registration_open = open
    yield
  ensure
    Rails.configuration.x.registration_open = previous
  end

  test "open sign-up shows the form and creates a user" do
    with_registration(true) do
      get new_user_session_url
      assert_select "a[href=?]", new_user_registration_path

      get new_user_registration_url
      assert_response :success

      assert_difference "User.count", 1 do
        post user_registration_url, params: { user: { username: "rincewind", email: "rincewind@example.com",
                                                      password: "octarine1", password_confirmation: "octarine1" } }
      end
    end
  end

  test "closed sign-up hides the link and refuses new accounts" do
    with_registration(false) do
      get new_user_session_url
      assert_select "a[href=?]", new_user_registration_path, count: 0

      get new_user_registration_url
      assert_redirected_to new_user_session_url

      assert_no_difference "User.count" do
        post user_registration_url, params: { user: { username: "rincewind", email: "rincewind@example.com",
                                                      password: "octarine1", password_confirmation: "octarine1" } }
      end
      assert_redirected_to new_user_session_url
      follow_redirect!
      assert_match "Sign-up is closed", response.body
    end
  end

  test "closed sign-up still lets a user edit their own account" do
    with_registration(false) do
      sign_in users(:admin)
      get edit_user_registration_url
      assert_response :success
    end
  end

  test "users edit their own name and cannot delete their account" do
    anna = users(:anna)
    sign_in anna
    get edit_user_registration_url
    assert_select "input[name='user[name]']"
    assert_select ".auth input[name=_method][value=delete]", 0

    put user_registration_url, params: { user: { name: "Anna P.", email: anna.email, current_password: "password" } }
    assert_equal "Anna P.", anna.reload.name

    assert_no_difference "User.count" do
      delete user_registration_url
    end
    assert_redirected_to edit_user_registration_url
  end
end
