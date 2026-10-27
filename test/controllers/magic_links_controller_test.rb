require "test_helper"

# One-time sign-in links (specs/public-form.md "Magic sign-in links").
class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { MagicLinksController::RATE_LIMIT_STORE.clear }

  def token_for(user) = user.generate_token_for(:magic_sign_in)

  test "a link shows a button; only the POST signs in, once" do
    token = token_for(users(:anna))
    get magic_link_url(token)
    assert_response :success
    assert_select "form[action=?][method=post] button", magic_link_session_path(token)
    assert_nil controller.current_user

    post magic_link_session_url(token, ticket: tickets(:printer).number)
    assert_redirected_to ticket_url(tickets(:printer))
    assert_equal "You are signed in.", flash[:notice]

    delete destroy_user_session_url
    post magic_link_session_url(token)
    assert_response :not_found
    assert_select "h2", "This sign-in link is not valid any more"
  end

  test "the return page must be visible to the user" do
    post magic_link_session_url(token_for(users(:anna)), ticket: tickets(:vpn).number)
    assert_redirected_to tickets_url
  end

  test "links expire after 24 hours and never sign in staff or deactivated users" do
    token = token_for(users(:anna))
    travel 25.hours do
      get magic_link_url(token)
      assert_response :not_found
    end
    post magic_link_session_url(token_for(users(:agent)))
    assert_response :not_found
    users(:anna).update!(deactivated_at: Time.current)
    post magic_link_session_url(token_for(users(:anna)))
    assert_response :not_found
    get magic_link_url("garbage")
    assert_response :not_found
  end

  test "asking for a link answers the same for every address and mails only requesters" do
    assert_enqueued_emails 1 do
      post magic_links_url, params: { email: " ANNA@example.com " }
    end
    assert_redirected_to new_user_session_url
    notice = flash[:notice]
    assert_no_enqueued_emails do
      post magic_links_url, params: { email: "nobody@example.com" }
      post magic_links_url, params: { email: users(:agent).email }
    end
    assert_equal notice, flash[:notice]

    mail = perform_enqueued_jobs { AccountMailer.with(user: users(:anna)).magic_link.deliver_now }
    assert_match %r{/magic/[^/\s"]+}, mail.text_part.body.to_s
  end

  test "asking for links is rate limited" do
    5.times { post magic_links_url, params: { email: "x#{rand(1000)}@example.com" } }
    post magic_links_url, params: { email: "y@example.com" }
    assert_equal "Too many requests. Please try again in a few minutes.", flash[:alert]
  end

  test "a requester without a chosen password sets one without the current password" do
    users(:anna).update!(password_chosen: false)
    sign_in users(:anna)
    get edit_user_registration_url
    assert_select "input[name='user[current_password]']", 0
    put user_registration_url, params: { user: { name: "Anna P", password: "new-secret-1", password_confirmation: "new-secret-1" } }
    assert users(:anna).reload.password_chosen?
    assert users(:anna).valid_password?("new-secret-1")

    put user_registration_url, params: { user: { name: "Anna Q" } }
    assert_equal "Anna P", users(:anna).reload.name
  end

  test "the sign-in page offers a sign-in link" do
    get new_user_session_url
    assert_select "a[href=?]", new_magic_link_path
  end
end
