# SMTP and IMAP settings of an organization (specs/organization-mail.md).
# Passwords are encrypted and write-only: a blank value in a form keeps the
# stored one, and remove_*_password clears it.
module MailSettings
  extend ActiveSupport::Concern

  SMTP_SECURITY = %w[starttls tls none].freeze

  included do
    encrypts :smtp_password, :imap_password

    attr_accessor :remove_smtp_password, :remove_imap_password

    normalizes :smtp_address, :imap_address, :smtp_username, :imap_username, :mail_from, :mailbox_address, :imap_folder,
               with: ->(value) { value.strip.presence }

    validates :smtp_security, inclusion: { in: SMTP_SECURITY }
    validates :smtp_port, :imap_port, numericality: { only_integer: true, in: 1..65_535 }
    with_options if: :smtp_enabled? do
      validates :smtp_address, presence: true
      validates :mail_from, presence: true
    end
    with_options if: :imap_enabled? do
      validates :imap_address, :imap_username, :imap_folder, presence: true
      validates :mailbox_address, presence: true
    end
    validate :mail_addresses_valid
    validate :mail_hosts_public

    before_save do
      self.smtp_password = nil if ActiveModel::Type::Boolean.new.cast(remove_smtp_password)
      self.imap_password = nil if ActiveModel::Type::Boolean.new.cast(remove_imap_password)
    end
  end

  # Settings for ActionMailer's SMTP delivery. Every key is set, so nothing
  # of the global settings leaks into an organization's delivery.
  def smtp_settings
    {
      address: smtp_address,
      port: smtp_port,
      domain: Mail::Address.new(mail_from).domain,
      user_name: smtp_username,
      password: smtp_password.presence,
      authentication: (:plain if smtp_username.present?),
      tls: smtp_security == "tls",
      enable_starttls: smtp_security == "starttls",
      enable_starttls_auto: false,
      openssl_verify_mode: "peer",
      open_timeout: 5,
      read_timeout: 10
    }
  end

  # The bare address of mail_from ("support@acme.example").
  def mail_from_address
    Mail::Address.new(mail_from).address if mail_from.present?
  rescue Mail::Field::ParseError
    nil
  end

  private

  EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  def mail_addresses_valid
    if mail_from.present?
      address = begin
        Mail::Address.new(mail_from).address
      rescue Mail::Field::ParseError
        nil
      end
      errors.add(:mail_from, :invalid) unless address&.match?(EMAIL)
    end
    errors.add(:mailbox_address, :invalid) if mailbox_address.present? && !mailbox_address.match?(EMAIL)
  end

  # No reaching services inside the server or its network through these
  # settings: IP literals must be public and "localhost" is refused.
  def mail_hosts_public
    { smtp_address: smtp_address, imap_address: imap_address }.each do |attribute, host|
      next if host.blank?

      errors.add(attribute, :private_host) if private_host?(host)
    end
  end

  def private_host?(host)
    return true if host.casecmp?("localhost") || host.downcase.end_with?(".localhost")

    ip = IPAddr.new(host.delete_prefix("[").delete_suffix("]"))
    ip.loopback? || ip.private? || ip.link_local? || ip.to_s == "0.0.0.0" || ip.to_s == "::"
  rescue IPAddr::InvalidAddressError
    false
  end
end
