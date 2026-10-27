require "test_helper"

# The Google setup wizard (specs/mail-oauth.md "Setup wizard").
class Admin::GoogleSetupControllerTest < ActionDispatch::IntegrationTest
  setup do
    AppSetting.current.update_columns(google_client_id: nil, google_client_secret: nil)
    sign_in users(:admin)
  end

  test "settings leads to the wizard, which starts with the kind of account" do
    get admin_settings_url
    assert_select "#google", /Not set up yet/
    assert_select "#google a.btn[href=?]", admin_google_setup_path(step: 1), "Set up Google"

    get admin_google_setup_url
    assert_response :success
    assert_select ".wizard-steps li", 6
    assert_select ".wizard-steps li[aria-current=step]", /Your Google account/
    assert_select "input[type=radio][name=kind][value=workspace][checked]"
    assert_select "input[type=radio][name=kind][value=gmail]"
  end

  test "the steps adapt to Workspace or personal Gmail and give every value to copy" do
    get admin_google_setup_url(step: 2, kind: "workspace")
    assert_select ".wizard-list", /choose Internal/
    assert_select "input#wizard-app-name[readonly][value=Stopan]"
    assert_select "input#wizard-support-email[value=?]", users(:admin).email
    assert_select "a[href='https://console.cloud.google.com/auth/branding'][target=_blank][rel~=noopener]"

    get admin_google_setup_url(step: 2, kind: "gmail")
    assert_select ".wizard-list", /choose External/
    assert_select ".callout", /7 days/
    get admin_google_setup_url(step: 2)
    assert_select ".wizard-list", /choose External/, "the choice is kept in the session"

    get admin_google_setup_url(step: 3)
    assert_select "input#wizard-scope[value=?]", "https://mail.google.com/"
    get admin_google_setup_url(step: 4)
    assert_select "input#wizard-redirect[value=?]", admin_mail_oauth_callback_url
    assert_select "a[href='https://console.cloud.google.com/auth/clients/create']"
  end

  test "the client is checked and saved, the secret stays write-only, and later steps need it" do
    get admin_google_setup_url(step: 5)
    assert_select ".wizard-steps li[aria-current=step]", /OAuth client/

    patch admin_google_setup_url, params: { app_setting: { google_client_id: "not-a-client", google_client_secret: "x" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /apps\.googleusercontent\.com/
    patch admin_google_setup_url, params: { app_setting: { google_client_id: "123-abc.apps.googleusercontent.com", google_client_secret: "" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /secret/i

    patch admin_google_setup_url, params: { app_setting: { google_client_id: "123-abc.apps.googleusercontent.com", google_client_secret: "s3cret" } }
    assert_redirected_to admin_google_setup_url(step: 5)
    assert AppSetting.current.reload.google_ready?
    get admin_google_setup_url(step: 4)
    assert_select "input[name='app_setting[google_client_secret]']:not([value])"
    assert_no_match(/s3cret/, response.body)

    get admin_google_setup_url(step: 5)
    assert_select "a.btn[href=?]", admin_organization_google_connect_path(organizations(:acme), return_to: "wizard"), "Connect with Google"
    get admin_settings_url
    assert_select "#google", /Ready\. 0 organizations are connected/
  end

  test "only administrators" do
    sign_in users(:agent)
    get admin_google_setup_url
    assert_redirected_to root_url
    patch admin_google_setup_url, params: { app_setting: { google_client_id: "x.apps.googleusercontent.com" } }
    assert_redirected_to root_url
  end
end
