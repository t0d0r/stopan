require "test_helper"

# Google accounts for organization mail (specs/mail-oauth.md): the OAuth
# client's requests and checks, the cached access token, and XOAUTH2 for
# IMAP and SMTP.
class GoogleMailTest < ActiveSupport::TestCase
  # GoogleOauth with its HTTP step replaced by canned answers.
  class CannedGoogle < GoogleOauth
    attr_reader :posts
    attr_accessor :answers

    def post(url, form)
      (@posts ||= []) << [ url, form ]
      answer = answers.shift
      raise answer if answer.is_a?(Exception)

      answer
    end
  end

  def id_token(claims)
    [ "e30", Base64.urlsafe_encode64(claims.to_json, padding: false), "sig" ].join(".")
  end

  setup do
    @org = organizations(:acme)
    @fake = FakeGoogleOauth.new
    MailConnection.oauth_client = @fake
    MailConnection::TOKENS.clear
  end

  teardown { MailConnection.oauth_client = nil }

  def connect!
    @org.create_mail_connection!(provider: "google", email: "support@acme.example", refresh_token: "refresh-1",
                                 connected_at: Time.current)
    @org.update!(mail_auth: "google", smtp_enabled: true, smtp_address: "smtp.gmail.com", smtp_port: 587,
                 smtp_security: "starttls", mail_from: "Acme <support@acme.example>", imap_enabled: true,
                 imap_address: "imap.gmail.com", imap_username: "support@acme.example", mailbox_address: "support@acme.example")
  end

  test "the authorize URL asks for offline mail access with PKCE and state" do
    google = GoogleOauth.new(client_id: "cid", client_secret: "secret")
    url = URI(google.authorize_url(redirect_uri: "https://desk.example/admin/mail_oauth/callback", state: "st", verifier: "v" * 64))
    query = URI.decode_www_form(url.query).to_h
    assert_equal "accounts.google.com", url.host
    assert_equal({ "client_id" => "cid", "response_type" => "code", "scope" => "https://mail.google.com/ openid email",
                   "access_type" => "offline", "prompt" => "consent", "state" => "st", "code_challenge_method" => "S256",
                   "code_challenge" => GoogleOauth.challenge("v" * 64) },
                 query.slice("client_id", "response_type", "scope", "access_type", "prompt", "state", "code_challenge_method", "code_challenge"))
    assert_not query.key?("client_secret")
    assert_equal Base64.urlsafe_encode64(Digest::SHA256.digest("abc"), padding: false), GoogleOauth.challenge("abc")
  end

  test "the code exchange sends the verifier and reads a verified email for this client" do
    google = CannedGoogle.new(client_id: "cid", client_secret: "secret")
    google.answers = [ { "access_token" => "at", "expires_in" => 3599, "refresh_token" => "rt",
                         "id_token" => id_token(aud: "cid", iss: "https://accounts.google.com", email: "Support@Acme.example", email_verified: true) } ]
    account = google.exchange(code: "c0de", verifier: "ver", redirect_uri: "https://desk.example/cb")
    assert_equal({ email: "support@acme.example", refresh_token: "rt", access_token: "at", expires_in: 3599 }, account)
    url, form = google.posts.sole
    assert_equal GoogleOauth::TOKEN_URL, url
    assert_equal({ code: "c0de", code_verifier: "ver", redirect_uri: "https://desk.example/cb", grant_type: "authorization_code",
                   client_id: "cid", client_secret: "secret" }, form)

    [ { aud: "other", iss: "https://accounts.google.com", email: "a@b.c", email_verified: true },
      { aud: "cid", iss: "https://evil.example", email: "a@b.c", email_verified: true },
      { aud: "cid", iss: "accounts.google.com", email: "a@b.c", email_verified: false } ].each do |claims|
      google.answers = [ { "refresh_token" => "rt", "id_token" => id_token(claims) } ]
      assert_raises(GoogleOauth::Error) { google.exchange(code: "c", verifier: "v", redirect_uri: "r") }
    end
    google.answers = [ { "id_token" => id_token(aud: "cid", iss: "accounts.google.com", email: "a@b.c", email_verified: true) } ]
    assert_raises(GoogleOauth::Error) { google.exchange(code: "c", verifier: "v", redirect_uri: "r") }
  end

  test "access tokens are cached until a minute before they expire; invalid_grant asks for reconnecting" do
    connect!
    connection = @org.mail_connection
    assert_equal "access-1", connection.access_token
    assert_equal "access-1", connection.access_token
    travel 59.minutes + 1.second do
      assert_equal "access-2", connection.access_token
    end

    MailConnection::TOKENS.clear
    @fake.invalid_grant = true
    assert_raises(GoogleOauth::InvalidGrant) { connection.access_token }
    assert_equal "needs_reconnect", connection.reload.status
    assert_not @org.reload.smtp_ready?
    assert_not @org.imap_ready?
  end

  test "SMTP signs in with XOAUTH2 as the account; passwords stay as they were" do
    connect!
    settings = @org.smtp_settings
    assert_equal [ :xoauth2, "support@acme.example", "access-1" ], settings.values_at(:authentication, :user_name, :password)
    assert_equal [ "smtp.gmail.com", 587, true ], settings.values_at(:address, :port, :enable_starttls)

    @org.update!(mail_auth: "password", smtp_username: "desk", smtp_password: "pw")
    assert_equal [ :plain, "desk", "pw" ], @org.smtp_settings.values_at(:authentication, :user_name, :password)
  end

  test "a mailer falls back to the global SMTP when Google gives no token" do
    connect!
    @fake.invalid_grant = true
    mail = OrganizationMailer.with(organization: @org, recipient: users(:admin)).test_email
    mail.message
    assert_not_equal "Acme <support@acme.example>", mail.from&.first
    assert_equal "needs_reconnect", @org.mail_connection.reload.status
  end

  test "the mailbox signs in with XOAUTH2, and the poller skips a connection that needs reconnecting" do
    connect!
    imap = Class.new do
      class << self
        attr_accessor :auths, :logins
      end
      def initialize(*, **) = nil
      def capable?(_name) = false
      def authenticate(mechanism, user, token) = (self.class.auths ||= []) << [ mechanism, user, token ]
      def login(*) = (self.class.logins ||= []) << :password
      def examine(_folder) = nil
      def uid_search(_keys) = []
      def logout = nil
      def disconnect = nil
      def disconnected? = true
    end
    MailboxCheck.new(@org, imap_class: imap).probe
    assert_equal [ [ "XOAUTH2", "support@acme.example", "access-1" ] ], imap.auths
    assert_nil imap.logins

    @org.mail_connection.update!(status: "needs_reconnect")
    assert_not @org.reload.imap_ready?
  end
end
