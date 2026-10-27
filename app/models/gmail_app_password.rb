# Points an organization's mail at Gmail with an app password, the wizard's
# path without Google Cloud (specs/mail-oauth.md "App password path").
class GmailAppPassword
  include ActiveModel::Model
  include ActiveModel::Attributes

  EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  attribute :organization_id, :integer
  attribute :email, :string
  attribute :app_password, :string

  validates :organization, presence: true
  validates :email, format: { with: EMAIL }
  validates :app_password, presence: true

  def organization
    Organization.find_by(id: organization_id) if organization_id
  end

  def email=(value)
    super(value.to_s.strip.presence)
  end

  # Google shows the password in groups of four letters; the spaces are not part of it.
  def app_password=(value)
    super(value.to_s.gsub(/\s/, "").presence)
  end

  # Revokes a Google account connected through OAuth first, then sets both
  # parts to Gmail, keeping a From and mailbox address already set.
  def save
    return false unless valid?

    organization = self.organization
    Organization.transaction do
      organization.mail_connection&.disconnect!
      organization.update!(
        mail_auth: "password", smtp_enabled: true, imap_enabled: true,
        smtp_address: "smtp.gmail.com", smtp_port: 587, smtp_security: "starttls",
        smtp_username: email, smtp_password: app_password, mail_from: organization.mail_from.presence || email,
        imap_address: "imap.gmail.com", imap_port: 993, imap_ssl: true,
        imap_username: email, imap_password: app_password, mailbox_address: organization.mailbox_address.presence || email
      )
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.full_messages.each { |message| errors.add(:base, message) }
    false
  end

  # Organizations that sign in to Gmail with a password.
  def self.organizations
    Organization.where(mail_auth: "password", imap_address: "imap.gmail.com").order(:name)
  end
end
