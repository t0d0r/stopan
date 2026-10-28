require "test_helper"

# Connecting an organization's mail to a Google account
# (specs/mail-oauth.md "Behaviour"), with a fake Google.
class Admin::MailOauthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @org = organizations(:acme)
    @fake = FakeGoogleOauth.new
    MailConnection.oauth_client = @fake
    MailConnection::TOKENS.clear
    AppSetting.current.update!(google_client_id: "cid.apps.googleusercontent.com", google_client_secret: "s3cret")
    sign_in users(:admin)
  end

  teardown { MailConnection.oauth_client = nil }

  def start
    get admin_organization_google_connect_url(@org)
    URI.decode_www_form(URI(response.location).query).to_h
  end

  test "connecting stores the account and points the organization's mail at Gmail" do
    get admin_organization_url(@org)
    assert_select "a.btn[href=?]", admin_organization_google_connect_path(@org), "Connect with Google"

    query = start
    assert_response :redirect
    assert_match %r{\Ahttps://accounts\.google\.test/auth}, response.location
    assert_equal admin_mail_oauth_callback_url, query["redirect_uri"]

    get admin_mail_oauth_callback_url(state: query["state"], code: "abc")
    assert_redirected_to admin_organization_url(@org)
    assert_equal "Connected with Google as support@acme.example. Mail goes in and out through this account.", flash[:notice]
    assert_equal [ "abc", admin_mail_oauth_callback_url ], @fake.exchanges.sole.values_at(0, 2)
    assert_equal query["code_challenge"], GoogleOauth.challenge(@fake.exchanges.sole[1]), "PKCE verifier matches the challenge"

    @org.reload
    connection = @org.mail_connection
    assert_equal [ "google", "support@acme.example", "connected" ], [ connection.provider, connection.email, connection.status ]
    assert_equal "refresh-abc", connection.refresh_token
    assert_no_match(/refresh-abc/, MailConnection.connection.select_value("SELECT refresh_token FROM mail_connections"), "encrypted")
    assert @org.google_mail?
    assert @org.smtp_ready? && @org.imap_ready?
    assert_equal [ "smtp.gmail.com", "imap.gmail.com", "support@acme.example" ], [ @org.smtp_address, @org.imap_address, @org.mailbox_address ]

    follow_redirect!
    assert_select ".org-mail__sign-in", /Google account support@acme\.example/
    assert_no_match(/refresh-abc|access-abc/, response.body)
    get edit_admin_organization_url(@org)
    assert_select "input[name='organization[smtp_password]']", 0
    assert_select ".callout", /Signed in with the Google account support@acme\.example/
  end

  test "a wrong, expired or reused state is refused and nothing is stored" do
    query = start
    get admin_mail_oauth_callback_url(state: "forged", code: "abc")
    assert_redirected_to admin_organizations_url
    assert_match(/expired or did not start here/, flash[:alert])

    # The state is single use: the failed attempt above consumed it.
    get admin_mail_oauth_callback_url(state: query["state"], code: "abc")
    assert_redirected_to admin_organizations_url

    query = start
    travel 11.minutes do
      get admin_mail_oauth_callback_url(state: query["state"], code: "abc")
      assert_redirected_to admin_organizations_url
    end
    assert_empty @fake.exchanges
    assert_nil @org.reload.mail_connection
  end

  test "a refusal at Google or a failed exchange changes nothing" do
    query = start
    get admin_mail_oauth_callback_url(state: query["state"], error: "access_denied")
    assert_redirected_to admin_organization_url(@org)
    assert_match(/did not give access/, flash[:alert])

    @fake.fail_exchange = true
    query = start
    get admin_mail_oauth_callback_url(state: query["state"], code: "abc")
    assert_match(/did not work/, flash[:alert])
    assert_nil @org.reload.mail_connection
    assert_not @org.google_mail?
  end

  test "without a client the organization page leads to the wizard and connecting is refused" do
    AppSetting.current.update_columns(google_client_id: nil, google_client_secret: nil)
    get admin_organization_url(@org)
    assert_select "a[href=?]", admin_organization_google_connect_path(@org), 0
    assert_select "a.btn[href=?]", admin_google_setup_path, "Set up Google"
    get admin_organization_google_connect_url(@org)
    assert_redirected_to admin_google_setup_url(step: "client")
    assert_match(/Google client ID and secret/, flash[:alert])
  end

  test "disconnecting revokes the token and turns the organization's mail off" do
    query = start
    get admin_mail_oauth_callback_url(state: query["state"], code: "abc")
    delete admin_organization_mail_oauth_url(@org)
    assert_redirected_to admin_organization_url(@org)
    assert_equal [ "refresh-abc" ], @fake.revoked
    @org.reload
    assert_nil @org.mail_connection
    assert_equal "password", @org.mail_auth
    assert_not @org.smtp_enabled?
    assert_not @org.imap_enabled?
  end

  test "only administrators" do
    sign_in users(:agent)
    get admin_organization_google_connect_url(@org)
    assert_redirected_to root_url
    delete admin_organization_mail_oauth_url(@org)
    assert_redirected_to root_url
  end

  test "connecting from the wizard returns to the wizard" do
    get admin_organization_google_connect_url(@org, return_to: "wizard")
    query = URI.decode_www_form(URI(response.location).query).to_h
    get admin_mail_oauth_callback_url(state: query["state"], code: "abc")
    assert_redirected_to admin_google_setup_url(step: "done")

    get admin_organization_google_connect_url(@org, return_to: "wizard")
    query = URI.decode_www_form(URI(response.location).query).to_h
    get admin_mail_oauth_callback_url(state: query["state"], error: "access_denied")
    assert_redirected_to admin_google_setup_url(step: "connect")
  end
end
