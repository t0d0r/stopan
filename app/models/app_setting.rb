# Settings of the whole service desk, kept in one row (specs/board.md,
# specs/translation.md).
class AppSetting < ApplicationRecord
  include RefreshesAdminPages

  # Themes (specs/ui.md "Themes"): notes is the Stickies look.
  LOOKS = %w[notes omarchy].freeze
  # How often the mailboxes are checked (specs/organization-mail.md "Fetching").
  MAILBOX_POLL_SECONDS = [ 60, 120, 300, 600, 900 ].freeze

  # Write-only in the form, like the organizations' mail passwords.
  encrypts :deepl_api_key, :google_client_secret
  attr_accessor :remove_deepl_api_key, :remove_google_client_secret

  normalizes :deepl_api_key, :google_client_id, :google_client_secret, with: ->(value) { value.strip.presence }

  validates :auto_postpone_days, numericality: { only_integer: true, in: 0..3650 }
  validates :default_look, inclusion: { in: LOOKS }
  validates :mailbox_poll_seconds, inclusion: { in: MAILBOX_POLL_SECONDS }
  # A Google OAuth client (specs/mail-oauth.md "Setup wizard").
  validates :google_client_id, format: { with: /\A[\w.-]+\.apps\.googleusercontent\.com\z/, message: :google_client_id },
                               allow_blank: true
  validate :google_client_needs_secret
  validate :translation_needs_a_key

  before_validation do
    self.deepl_api_key = nil if ActiveModel::Type::Boolean.new.cast(remove_deepl_api_key)
    self.google_client_secret = nil if ActiveModel::Type::Boolean.new.cast(remove_google_client_secret)
  end

  def self.current
    first || create!
  end

  # The stored key, else DEEPL_API_KEY from the environment.
  def deepl_key
    deepl_api_key.presence || ENV["DEEPL_API_KEY"].presence
  end

  def google_ready?
    google_client_id.present? && google_client_secret.present?
  end

  private

  def google_client_needs_secret
    errors.add(:google_client_secret, :blank) if google_client_id.present? && google_client_secret.blank?
  end

  def translation_needs_a_key
    errors.add(:deepl_api_key, :required_for_translation) if translation_enabled? && deepl_key.blank?
  end
end
