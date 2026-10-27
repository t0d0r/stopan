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
    assert_select "#google a.btn[href=?]", admin_google_setup_path(step: "account"), "Set up Google"

    get admin_google_setup_url
    assert_response :success
    assert_select ".wizard-steps li", 6
    assert_select ".wizard-steps li[aria-current=step]", /Your Google account/
    assert_select "input[type=radio][name=kind][value=workspace][checked]"
    assert_select "input[type=radio][name=kind][value=gmail]"
  end

  test "the steps adapt to Workspace or personal Gmail and give every value to copy" do
    get admin_google_setup_url(kind: "workspace")
    assert_select ".wizard-list", /choose Internal/
    assert_select "input#wizard-app-name[readonly][value=Stopan]"
    assert_select "input#wizard-support-email[value=?]", users(:admin).email
    assert_select "a[href='https://console.cloud.google.com/auth/branding'][target=_blank][rel~=noopener]"

    get admin_google_setup_url(kind: "gmail")
    assert_select ".wizard-list", /choose External/
    assert_select ".callout", /7 days/
    get admin_google_setup_url(step: "project")
    assert_select ".wizard-list", /choose External/, "the choice is kept in the session"

    get admin_google_setup_url(step: "access")
    assert_select "input#wizard-scope[value=?]", "https://mail.google.com/"
    get admin_google_setup_url(step: "client")
    assert_select "input#wizard-redirect[value=?]", admin_mail_oauth_callback_url
    assert_select "a[href='https://console.cloud.google.com/auth/clients/create']"
  end

  test "the client is checked and saved, the secret stays write-only, and later steps need it" do
    get admin_google_setup_url(step: "connect")
    assert_select ".wizard-steps li[aria-current=step]", /OAuth client/

    patch admin_google_setup_url, params: { app_setting: { google_client_id: "not-a-client", google_client_secret: "x" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /apps\.googleusercontent\.com/
    patch admin_google_setup_url, params: { app_setting: { google_client_id: "123-abc.apps.googleusercontent.com", google_client_secret: "" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /secret/i

    patch admin_google_setup_url, params: { app_setting: { google_client_id: "123-abc.apps.googleusercontent.com", google_client_secret: "s3cret" } }
    assert_redirected_to admin_google_setup_url(step: "connect")
    assert AppSetting.current.reload.google_ready?
    get admin_google_setup_url(step: "client")
    assert_select "input[name='app_setting[google_client_secret]']:not([value])"
    assert_no_match(/s3cret/, response.body)

    get admin_google_setup_url(step: "connect")
    assert_select "a.btn[href=?]", admin_organization_google_connect_path(organizations(:acme), return_to: "wizard"), "Connect with Google"
    get admin_settings_url
    assert_select "#google", /Ready\. 0 organizations are connected/
  end

  test "the app password path needs no Google Cloud and has its own four steps" do
    get admin_google_setup_url
    assert_select "input[type=radio][name=kind][value=app_password]"
    assert_select "label", /Gmail with an app password \(no Google Cloud\)/

    get admin_google_setup_url(kind: "app_password")
    assert_select ".wizard-steps li", 4
    assert_select ".wizard-steps li[aria-current=step]", /App password/
    assert_select "a[href='https://myaccount.google.com/apppasswords'][target=_blank][rel~=noopener]"
    assert_select "a[href='https://myaccount.google.com/signinoptions/twosv']"
    assert_select "input#wizard-app-password-name[readonly][value=Stopan]"

    get admin_google_setup_url(step: "mailbox")
    assert_select "form[action=?]", mailbox_admin_google_setup_path
    assert_select "select[name='gmail_app_password[organization_id]'] option", 2
    assert_select "input[type=password][name='gmail_app_password[app_password]']:not([value])"

    # An OAuth step leaves the app password path (the OAuth callback returns to one).
    get admin_google_setup_url(step: "project")
    assert_select ".wizard-steps li", 6
  end

  test "saving the app password points the organization at Gmail and revokes a Google connection" do
    fake = FakeGoogleOauth.new
    MailConnection.oauth_client = fake
    acme = organizations(:acme)
    acme.update!(mail_from: "Acme Help <help@acme.example>")
    acme.create_mail_connection!(provider: "google", email: "old@acme.example", refresh_token: "refresh-old", status: "connected",
                                 connected_at: Time.current)

    patch mailbox_admin_google_setup_url, params: { gmail_app_password: { organization_id: acme.id, email: "nope", app_password: "" } }
    assert_response :unprocessable_content
    assert_select ".form-errors li", 2
    assert_select ".wizard-steps li", 4

    patch mailbox_admin_google_setup_url,
          params: { gmail_app_password: { organization_id: acme.id, email: " acme.help@gmail.com ", app_password: "abcd efgh ijkl mnop" } }
    assert_redirected_to admin_google_setup_url(step: "saved")
    acme.reload
    assert_equal "password", acme.mail_auth
    assert_nil acme.mail_connection
    assert_equal [ "refresh-old" ], fake.revoked
    assert acme.smtp_ready? && acme.imap_ready?
    assert_equal [ "smtp.gmail.com", 587, "starttls", "acme.help@gmail.com", "abcdefghijklmnop" ],
                 [ acme.smtp_address, acme.smtp_port, acme.smtp_security, acme.smtp_username, acme.smtp_password ]
    assert_equal [ "imap.gmail.com", 993, true, "acme.help@gmail.com", "abcdefghijklmnop" ],
                 [ acme.imap_address, acme.imap_port, acme.imap_ssl, acme.imap_username, acme.imap_password ]
    assert_equal "Acme Help <help@acme.example>", acme.mail_from, "a From already set is kept"
    assert_equal "acme.help@gmail.com", acme.mailbox_address
    assert_no_match(/abcdefghijklmnop/, Organization.connection.select_value("SELECT smtp_password FROM organizations WHERE id = #{acme.id}"))

    follow_redirect!
    assert_select ".wizard-steps li", 4
    assert_select ".share-list__item", /Acme Bakery.*acme\.help@gmail\.com/m
    assert_no_match(/abcdefghijklmnop/, response.body)
  ensure
    MailConnection.oauth_client = nil
  end

  test "only administrators" do
    sign_in users(:agent)
    get admin_google_setup_url
    assert_redirected_to root_url
    patch admin_google_setup_url, params: { app_setting: { google_client_id: "x.apps.googleusercontent.com" } }
    assert_redirected_to root_url
  end
end
