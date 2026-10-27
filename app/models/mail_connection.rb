# An organization's mail signed in with a Google account instead of a
# password (specs/mail-oauth.md): the account's address and its refresh
# token (encrypted). Access tokens are kept in memory until shortly
# before they expire.
class MailConnection < ApplicationRecord
  PROVIDERS = %w[google].freeze
  STATUSES = %w[connected needs_reconnect].freeze
  TOKENS = Concurrent::Map.new

  belongs_to :organization

  encrypts :refresh_token

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :email, :refresh_token, presence: true

  # Tests replace the OAuth client; nothing here talks to the network otherwise.
  class_attribute :oauth_client, default: nil

  def self.client
    oauth_client || GoogleOauth.from_settings
  end

  def connected?
    status == "connected"
  end

  # A current access token, refreshed when needed. A refused refresh token
  # marks the connection for reconnecting and raises GoogleOauth::InvalidGrant.
  def access_token
    cached = TOKENS[id]
    return cached.first if cached && cached.last > 1.minute.from_now

    token, seconds = self.class.client.refresh(refresh_token)
    TOKENS[id] = [ token, Time.current + seconds ]
    token
  rescue GoogleOauth::InvalidGrant => e
    update_columns(status: "needs_reconnect", last_error: e.message, updated_at: Time.current)
    forget_token
    raise
  end

  def remember_token(token, seconds)
    TOKENS[id] = [ token, Time.current + seconds ]
  end

  def forget_token
    TOKENS.delete(id)
  end
end
