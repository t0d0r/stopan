# Settings of the whole service desk, kept in one row (specs/board.md,
# specs/translation.md).
class AppSetting < ApplicationRecord
  include RefreshesAdminPages

  # Themes (specs/ui.md "Themes"): notes is the Stickies look.
  LOOKS = %w[notes omarchy].freeze
  # How often the mailboxes are checked (specs/organization-mail.md "Fetching").
  MAILBOX_POLL_SECONDS = [ 60, 120, 300, 600, 900 ].freeze
  # Order of the ticket timeline (specs/timeline.md "Order of the timeline").
  TIMELINE_ORDERS = %w[oldest_first newest_first].freeze

  # Write-only in the form, like the organizations' mail passwords.
  encrypts :deepl_api_key, :google_client_secret
  attr_accessor :remove_deepl_api_key, :remove_google_client_secret

  normalizes :deepl_api_key, :google_client_id, :google_client_secret, with: ->(value) { value.strip.presence }

  validates :auto_postpone_days, :auto_done_days, numericality: { only_integer: true, in: 0..3650 }
  validates :default_look, inclusion: { in: LOOKS }
  validates :mailbox_poll_seconds, inclusion: { in: MAILBOX_POLL_SECONDS }
  validates :timeline_order, inclusion: { in: TIMELINE_ORDERS }
  # A Google OAuth client (specs/mail-oauth.md "Setup wizard").
  validates :google_client_id, format: { with: /\A[\w.-]+\.apps\.googleusercontent\.com\z/, message: :google_client_id },
                               allow_blank: true
  validate :google_client_needs_secret
  validate :translation_needs_a_key
  validate :sla_targets_valid

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

  # Target in minutes for a priority and kind (specs/sla.md), or nil.
  def sla_minutes(priority, kind)
    value = sla_targets.dig(priority.to_s, kind.to_s).to_i
    value if value.positive?
  end

  # The same in hours, as the settings form shows it.
  def sla_hours(priority, kind)
    minutes = sla_minutes(priority, kind)
    minutes && (minutes % 60).zero? ? minutes / 60 : minutes&.fdiv(60)
  end

  # From the form: {"urgent" => {"first_response" => "1.5", ...}, ...} in
  # hours. Blank and 0 mean no target; anything that is not a number is
  # kept as it is for the validation to refuse.
  def sla_hours=(hours)
    self.sla_targets = Ticket::PRIORITIES.to_h do |priority|
      [ priority, Sla::KINDS.to_h do |kind|
        value = hours.to_h.dig(priority, kind).to_s.strip.tr(",", ".")
        [ kind, value.empty? ? 0 : (Float(value, exception: false)&.then { |number| (number * 60).round } || value) ]
      end ]
    end
  end

  def google_ready?
    google_client_id.present? && google_client_secret.present?
  end

  private

  def google_client_needs_secret
    errors.add(:google_client_secret, :blank) if google_client_id.present? && google_client_secret.blank?
  end

  # Whole minutes from 0 to a year, for known priorities and kinds only.
  def sla_targets_valid
    targets = sla_targets
    valid = targets.is_a?(Hash) && (targets.keys - Ticket::PRIORITIES).empty? && targets.values.all? do |kinds|
      kinds.is_a?(Hash) && (kinds.keys - Sla::KINDS).empty? &&
        kinds.values.all? { |minutes| minutes.is_a?(Integer) && minutes.between?(0, Sla::MAX_MINUTES) }
    end
    errors.add(:sla_targets, :invalid) unless valid
  end

  def translation_needs_a_key
    errors.add(:deepl_api_key, :required_for_translation) if translation_enabled? && deepl_key.blank?
  end
end
