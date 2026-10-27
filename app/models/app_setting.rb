# Settings of the whole service desk, kept in one row (specs/board.md,
# specs/translation.md).
class AppSetting < ApplicationRecord
  include RefreshesAdminPages

  # Write-only in the form, like the organizations' mail passwords.
  encrypts :deepl_api_key
  attr_accessor :remove_deepl_api_key

  normalizes :deepl_api_key, with: ->(key) { key.strip.presence }

  validates :auto_postpone_days, numericality: { only_integer: true, in: 0..3650 }
  validate :translation_needs_a_key

  before_validation do
    self.deepl_api_key = nil if ActiveModel::Type::Boolean.new.cast(remove_deepl_api_key)
  end

  def self.current
    first || create!
  end

  # The stored key, else DEEPL_API_KEY from the environment.
  def deepl_key
    deepl_api_key.presence || ENV["DEEPL_API_KEY"].presence
  end

  private

  def translation_needs_a_key
    errors.add(:deepl_api_key, :required_for_translation) if translation_enabled? && deepl_key.blank?
  end
end
