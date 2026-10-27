# A machine translation of a message (the ticket's description or a
# comment) into one UI language, for staff (specs/translation.md). It is
# current while the message text has the digest it was made from.
class Translation < ApplicationRecord
  MAX_LENGTH = 20_000

  class TooLong < StandardError; end

  belongs_to :translatable, polymorphic: true

  validates :target_language, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }

  # Tests replace the client; nothing here talks to the network otherwise.
  class_attribute :client, default: nil

  def self.text_of(message)
    message.is_a?(Ticket) ? message.description : message.body
  end

  def self.digest(text)
    Digest::SHA256.hexdigest(text.to_s)
  end

  # Translation is offered when an administrator switched it on and a key is set.
  def self.available?
    setting = AppSetting.current
    setting.translation_enabled? && setting.deepl_key.present?
  end

  def self.for(message, language)
    translation = find_by(translatable: message, target_language: language.to_s)
    translation if translation&.source_digest == digest(text_of(message))
  end

  # Asks DeepL and stores the result, replacing an older translation of the
  # same message and language. Raises TooLong or DeeplClient::Error.
  def self.translate!(message, language)
    text = text_of(message).to_s
    raise TooLong if text.length > MAX_LENGTH

    translated, source = (client || DeeplClient.new).translate(text, target: language)
    translation = find_or_initialize_by(translatable: message, target_language: language.to_s)
    translation.update!(text: translated, source_language: source, source_digest: digest(text))
    translation
  end

  def already_in_target?
    source_language == target_language
  end
end
