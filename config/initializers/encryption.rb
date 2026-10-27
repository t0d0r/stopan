# Active Record encryption for the organizations' mail passwords
# (specs/organization-mail.md). The keys are derived from SECRET_KEY_BASE,
# so no extra secret has to be kept; changing SECRET_KEY_BASE makes the
# stored passwords unreadable and they must be entered again.
Rails.application.configure do
  derive = ->(purpose) { Rails.application.key_generator.generate_key("stopan/encryption/#{purpose}", 32).unpack1("H*") }
  config.active_record.encryption.primary_key = derive.call("primary")
  config.active_record.encryption.deterministic_key = derive.call("deterministic")
  config.active_record.encryption.key_derivation_salt = derive.call("salt")
end
