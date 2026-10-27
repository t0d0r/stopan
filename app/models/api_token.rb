# A personal token for the JSON API (specs/api.md "Tokens"). Only the
# SHA-256 digest is kept; the token is shown once, when it is made.
class ApiToken < ApplicationRecord
  PREFIX = "stopan_"
  MAX_PER_USER = 10
  EXPIRIES = [ nil, 30, 90, 365 ].freeze
  USE_INTERVAL = 1.minute

  belongs_to :user

  attr_reader :plain_token

  normalizes :name, with: ->(value) { value.squish }

  validates :name, presence: true, length: { maximum: 60 }
  validate :within_limit, on: :create

  before_validation :generate, on: :create

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # The live token for a presented secret, or nil: unknown, expired, or a
  # deactivated user's.
  def self.authenticate(token)
    return if token.blank? || !token.start_with?(PREFIX)

    api_token = includes(:user).find_by(token_digest: digest(token))
    api_token if api_token && !api_token.expired? && !api_token.user.deactivated?
  end

  # The form's expiry choice; only the date is kept.
  def expires_in_days
    nil
  end

  # "30" -> 30 days from now; blank or unknown -> never.
  def expires_in_days=(days)
    days = days.to_s.to_i
    self.expires_at = EXPIRIES.include?(days) && days.positive? ? days.days.from_now : nil
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def touch_used
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < USE_INTERVAL.ago
  end

  private

  def generate
    @plain_token = PREFIX + SecureRandom.base58(40)
    self.token_digest = self.class.digest(@plain_token)
    self.token_hint = @plain_token.last(4)
  end

  def within_limit
    errors.add(:base, :too_many_tokens, count: MAX_PER_USER) if user && user.api_tokens.count >= MAX_PER_USER
  end
end
