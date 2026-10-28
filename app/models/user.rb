class User < ApplicationRecord
  include RefreshesAdminPages

  ROLES = %w[requester agent admin].freeze
  STAFF_ROLES = %w[agent admin].freeze

  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :trackable, :validatable, :lockable

  has_many :memberships, dependent: :destroy
  has_many :notifications, dependent: :delete_all
  has_many :api_tokens, dependent: :delete_all
  has_many :organizations, -> { order(:name) }, through: :memberships
  has_many :requested_tickets, class_name: "Ticket", foreign_key: :requester_id,
           inverse_of: :requester, dependent: :restrict_with_error
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: :assignee_id,
           inverse_of: :assignee, dependent: :restrict_with_error
  has_many :comments, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_error
  has_many :ticket_events, foreign_key: :actor_id, inverse_of: :actor, dependent: :restrict_with_error
  has_many :revisions, foreign_key: :editor_id, inverse_of: :editor, dependent: :restrict_with_error
  has_many :impersonations, dependent: :restrict_with_error
  has_many :impersonations_made, class_name: "Impersonation", foreign_key: :admin_id, inverse_of: :admin,
                                 dependent: :restrict_with_error

  # One-time sign-in links for requesters (specs/public-form.md "Magic
  # sign-in links"): any sign-in changes current_sign_in_at and so ends
  # every link issued before it.
  generates_token_for :magic_sign_in, expires_in: 24.hours do
    current_sign_in_at
  end

  normalizes :username, with: ->(username) { username.strip.presence }
  normalizes :name, with: ->(name) { name.strip.squish.presence }

  validates :username, uniqueness: { case_sensitive: false }, length: { maximum: 60 }, allow_nil: true
  validates :name, length: { maximum: 120 }
  validates :role, inclusion: { in: ROLES }
  validates :locale, :language, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }, allow_nil: true

  scope :active, -> { where(deactivated_at: nil) }
  scope :new_ticket_subscribers, -> { active.staff.where(notify_new_tickets: true) }
  scope :staff, -> { where(role: STAFF_ROLES) }
  scope :requesters, -> { where(role: "requester") }
  scope :with_membership, -> { where(id: Membership.select(:user_id)) }
  scope :ordered, -> { order(Arel.sql("lower(coalesce(users.name, users.username, users.email))")) }
  scope :search, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip.downcase)}%"
    where("ulower(coalesce(users.name, '')) LIKE :p ESCAPE '\\' OR ulower(coalesce(users.username, '')) LIKE :p ESCAPE '\\' " \
          "OR ulower(users.email) LIKE :p ESCAPE '\\'", p: pattern)
  }

  # The sign-in form has one field, which may hold the username or the email.
  def self.find_for_database_authentication(conditions)
    value = conditions[authentication_keys.first].to_s.strip.downcase
    where("lower(username) = :value OR lower(email) = :value", value: value).first
  end

  def display_name
    name.presence || username.presence || email
  end

  def requester?
    role == "requester"
  end

  def agent?
    role == "agent"
  end

  def admin?
    role == "admin"
  end

  def staff?
    STAFF_ROLES.include?(role)
  end

  def deactivated?
    deactivated_at.present?
  end

  # Organizations whose tickets the user sees: all for administrators,
  # their own for everyone else (specs/roles.md).
  def visible_organizations
    admin? ? Organization.all : organizations
  end

  def member_of?(organization)
    organization && memberships.exists?(organization_id: organization.id)
  end

  # The language of an email to this user (specs/notifications.md
  # "Language"): their own choice, else for a requester the organization's
  # email language, else the browser's, else English.
  def mail_locale(organization = nil)
    language.presence || (organization&.mail_locale if requester?).presence || locale.presence || I18n.default_locale
  end

  # The organization a mail not tied to a ticket speaks for: the only one.
  def only_organization
    organizations.first if organizations.one?
  end

  # A language chosen in the header or on the account page (specs/ui.md
  # "Language"); blank goes back to the browser's. Emails follow the choice.
  def choose_language!(value)
    language = value.presence_in(I18n.available_locales.map(&:to_s))
    update!(language: language, locale: language || locale)
  end

  # Devise asks this on sign-in and on every request; a deactivated user is
  # signed out at once.
  def active_for_authentication?
    super && !deactivated?
  end

  def inactive_message
    deactivated? ? :deactivated : super
  end

  # Unsolved tickets assigned to this user lose their assignee, with an
  # audit event naming who did it. Used when a user stops being staff or is
  # deactivated (admin.md).
  def release_assigned_tickets!(actor)
    assigned_tickets.unsolved.find_each do |ticket|
      ticket.apply_changes!({ assignee_id: nil }, actor: actor)
    end
  end

  # History keeps its people, so only users without any can be deleted.
  def magic_sign_in_allowed?
    role == "requester" && active_for_authentication? && !access_locked?
  end

  def ticket_history?
    requested_tickets.exists? || assigned_tickets.exists? || comments.exists? || ticket_events.exists? ||
      revisions.exists? || impersonations.exists? || impersonations_made.exists?
  end

  # The ids among user_ids that have ticket history, in one query per table
  # (for lists).
  def self.ids_with_ticket_history(user_ids)
    [ Ticket.where(requester_id: user_ids).distinct.pluck(:requester_id),
      Ticket.where(assignee_id: user_ids).distinct.pluck(:assignee_id),
      Comment.where(author_id: user_ids).distinct.pluck(:author_id),
      TicketEvent.where(actor_id: user_ids).distinct.pluck(:actor_id),
      Revision.where(editor_id: user_ids).distinct.pluck(:editor_id),
      Impersonation.where(user_id: user_ids).distinct.pluck(:user_id),
      Impersonation.where(admin_id: user_ids).distinct.pluck(:admin_id) ].flatten.to_set
  end
end
