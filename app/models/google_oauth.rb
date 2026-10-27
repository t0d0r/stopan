require "net/http"

# Google's OAuth 2.0 endpoints for organization mail (specs/mail-oauth.md):
# the authorization URL with PKCE, the code exchange, refreshing and
# revoking. Errors raise GoogleOauth::Error (InvalidGrant when the refresh
# token no longer works) without tokens or secrets in the message.
class GoogleOauth
  class Error < StandardError; end
  class InvalidGrant < Error; end

  AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
  REVOKE_URL = "https://oauth2.googleapis.com/revoke".freeze
  SCOPE = "https://mail.google.com/ openid email".freeze
  TIMEOUT = 10

  def initialize(client_id:, client_secret:)
    @client_id = client_id.to_s
    @client_secret = client_secret.to_s
  end

  def self.from_settings
    setting = AppSetting.current
    new(client_id: setting.google_client_id, client_secret: setting.google_client_secret)
  end

  def self.verifier
    SecureRandom.urlsafe_base64(48)
  end

  def self.challenge(verifier)
    Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
  end

  def authorize_url(redirect_uri:, state:, verifier:)
    query = { client_id: @client_id, redirect_uri: redirect_uri, response_type: "code", scope: SCOPE,
              access_type: "offline", prompt: "consent", include_granted_scopes: "false", state: state,
              code_challenge: self.class.challenge(verifier), code_challenge_method: "S256" }
    "#{AUTHORIZE_URL}?#{URI.encode_www_form(query)}"
  end

  # Returns { email:, refresh_token:, access_token:, expires_in: }.
  def exchange(code:, verifier:, redirect_uri:)
    body = post(TOKEN_URL, code: code, code_verifier: verifier, redirect_uri: redirect_uri,
                           grant_type: "authorization_code", client_id: @client_id, client_secret: @client_secret)
    claims = id_token_claims(body["id_token"])
    raise Error, "Google did not return a refresh token" if body["refresh_token"].blank?
    raise Error, "Google did not confirm the account's email" unless claims["email_verified"] && claims["email"].present?

    { email: claims["email"].downcase, refresh_token: body["refresh_token"],
      access_token: body["access_token"], expires_in: body["expires_in"].to_i }
  end

  # Returns [access token, seconds it is valid].
  def refresh(refresh_token)
    body = post(TOKEN_URL, refresh_token: refresh_token, grant_type: "refresh_token",
                           client_id: @client_id, client_secret: @client_secret)
    [ body.fetch("access_token"), body["expires_in"].to_i ]
  end

  # Best effort; a token Google no longer knows is already revoked.
  def revoke(token)
    post(REVOKE_URL, token: token)
  rescue Error
    nil
  end

  private

  def post(url, form)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                   open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.post(uri.path, URI.encode_www_form(form), "Content-Type" => "application/x-www-form-urlencoded")
    end
    body = response.body.present? ? JSON.parse(response.body) : {}
    return body if response.is_a?(Net::HTTPSuccess)

    raise InvalidGrant, "Google refused the token (invalid_grant)" if body["error"] == "invalid_grant"

    raise Error, "Google answered #{response.code} #{body["error"]}".strip
  rescue JSON::ParserError, KeyError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise Error, "Google request failed (#{e.class})"
  end

  # The ID token comes straight from Google's token endpoint over TLS, so
  # its payload is read without checking the signature (OpenID Connect
  # Core 3.1.3.7); only the audience and issuer are checked.
  def id_token_claims(token)
    payload = token.to_s.split(".")[1].to_s
    claims = JSON.parse(Base64.urlsafe_decode64(payload + "=" * (-payload.size % 4)))
    raise Error, "Google's ID token is for another client" unless claims["aud"] == @client_id
    raise Error, "Google's ID token has another issuer" unless claims["iss"].in?(%w[https://accounts.google.com accounts.google.com])

    claims
  rescue ArgumentError, JSON::ParserError
    raise Error, "Google's ID token could not be read"
  end
end
