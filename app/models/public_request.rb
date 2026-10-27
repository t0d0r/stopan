# A request sent through an organization's public page, without an
# account (specs/public-form.md). The email address is the identity: an
# unknown address gets a new requester, a known requester gets the ticket,
# and staff or deactivated addresses get nothing, without the page
# telling the difference.
class PublicRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  EMAIL = URI::MailTo::EMAIL_REGEXP

  attribute :name, :string
  attribute :email, :string
  attribute :subject, :string
  attribute :description, :string
  attribute :markdown, :boolean, default: false
  # The page's language, kept for a new requester's emails.
  attr_accessor :organization, :locale

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: EMAIL }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :description, presence: true, length: { maximum: 20_000 }

  # Creates the ticket (and the requester when needed) and mails the
  # confirmation. Returns the ticket, or nil for an address that may not
  # open tickets this way.
  def submit
    ticket = User.transaction do
      requester = requester_for_email
      next unless requester

      Membership.find_or_create_by!(user: requester, organization: organization)
      Ticket.create!(subject: subject, description: description, markdown: markdown, requester: requester,
                     organization: organization, actor: requester, source: "web_form")
    end
    if ticket
      PublicRequestMailer.with(ticket: ticket).received.deliver_later
    else
      Rails.logger.info("Public request for organization #{organization.id} ignored: staff or deactivated address")
    end
    ticket
  end

  private

  def requester_for_email
    user = User.find_by("lower(email) = ?", email.strip.downcase)
    return user if user&.requester? && !user.deactivated?
    return if user

    User.create!(name: name, email: email.strip, password: SecureRandom.base58(32), role: "requester",
                 password_chosen: false, locale: locale)
  end
end
