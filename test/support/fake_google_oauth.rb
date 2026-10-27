# A stand-in for GoogleOauth in tests (specs/mail-oauth.md "Tests"): no
# network; records what was asked.
class FakeGoogleOauth
  attr_accessor :email, :fail_exchange, :invalid_grant
  attr_reader :refreshes, :revoked, :exchanges

  def initialize(email: "support@acme.example")
    @email = email
    @refreshes = 0
    @revoked = []
    @exchanges = []
  end

  def authorize_url(redirect_uri:, state:, verifier:)
    "https://accounts.google.test/auth?#{URI.encode_www_form(redirect_uri: redirect_uri, state: state,
                                                              code_challenge: GoogleOauth.challenge(verifier))}"
  end

  def exchange(code:, verifier:, redirect_uri:)
    raise GoogleOauth::Error, "Google answered 400 invalid_request" if fail_exchange

    exchanges << [ code, verifier, redirect_uri ]
    { email: email, refresh_token: "refresh-#{code}", access_token: "access-#{code}", expires_in: 3600 }
  end

  def refresh(_refresh_token)
    raise GoogleOauth::InvalidGrant, "Google refused the token (invalid_grant)" if invalid_grant

    @refreshes += 1
    [ "access-#{@refreshes}", 3600 ]
  end

  def revoke(token)
    revoked << token
  end
end
