require "test_helper"

# specs/auth.md "Rate limits"
class SignInRateLimitTest < ActionDispatch::IntegrationTest
  test "sign-in attempts from one address are limited" do
    20.times { |i| post user_session_url, params: { user: { email: "nobody#{i}", password: "wrong" } } }
    assert_response :unprocessable_content

    post user_session_url, params: { user: { email: "anna", password: "password" } }
    assert_redirected_to new_user_session_url
    assert_equal "Too many sign-in attempts. Please try again in a few minutes.", flash[:alert]
    get tickets_url
    assert_redirected_to new_user_session_url
  end

  test "the refusal is in the visitor's language and counts no failed attempt" do
    20.times { |i| post user_session_url, params: { user: { email: "nobody#{i}", password: "wrong" } } }

    post user_session_url, params: { user: { email: "anna", password: "wrong" } },
                           headers: { "Accept-Language" => "bg" }
    assert_match "Твърде много опити за вход", flash[:alert]
    assert_equal 0, users(:anna).reload.failed_attempts
  end

  test "another address still signs in" do
    20.times { |i| post user_session_url, params: { user: { email: "nobody#{i}", password: "wrong" } } }

    post user_session_url, params: { user: { email: "anna", password: "password" } },
                           headers: { "REMOTE_ADDR" => "203.0.113.9" }
    assert_redirected_to root_url
  end

  test "the sign-in page itself is never limited" do
    25.times { get new_user_session_url }
    assert_response :success
  end

  test "password reset requests from one address are limited" do
    5.times { |i| post user_password_url, params: { user: { email: "x#{i}@example.com" } } }
    assert_redirected_to new_user_session_url

    assert_no_enqueued_emails do
      post user_password_url, params: { user: { email: users(:anna).email } }
    end
    assert_redirected_to new_user_password_url
    assert_equal "Too many requests. Please try again in a few minutes.", flash[:alert]
  end

  test "password reset requests for one address are limited across addresses" do
    5.times do |i|
      post user_password_url, params: { user: { email: " #{users(:anna).email.upcase} " } },
                              headers: { "REMOTE_ADDR" => "203.0.113.#{i + 1}" }
    end

    assert_no_enqueued_emails do
      post user_password_url, params: { user: { email: users(:anna).email } },
                              headers: { "REMOTE_ADDR" => "203.0.113.99" }
    end
    assert_equal "Too many requests. Please try again in a few minutes.", flash[:alert]
  end
end
