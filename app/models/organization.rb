class Organization < ApplicationRecord
  include RefreshesAdminPages
  include MailSettings

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :tickets, dependent: :restrict_with_error

  # URL name of the public request page (specs/public-form.md).
  SLUG = /\A[a-z0-9](?:[a-z0-9-]{0,58}[a-z0-9])?\z/

  normalizes :name, with: ->(name) { name.squish }
  normalizes :slug, with: ->(slug) { slug.strip.downcase.presence }
  normalizes :mail_locale, with: ->(locale) { locale.strip.presence }

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :notes, length: { maximum: 5_000 }
  validates :slug, presence: true, length: { minimum: 2 }, format: { with: SLUG }, uniqueness: true
  validates :public_intro, length: { maximum: 1_000 }
  validates :mail_locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }, allow_nil: true
  validate :allowed_senders_valid

  # One address or @domain per line, lower-case, without blanks or
  # duplicates (specs/public-form.md "Allowed senders").
  normalizes :public_allowed_senders, with: ->(text) {
    text.to_s.split(/[\r\n,;]+/).map { |entry| entry.strip.downcase }.reject(&:empty?).uniq.join("\n").presence
  }

  before_validation :fill_slug, on: :create

  scope :with_public_form, -> { where(public_form: true) }

  scope :ordered, -> { order(Arel.sql("lower(organizations.name)")) }
  scope :search, ->(query) {
    where("ulower(organizations.name) LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(query.to_s.strip.downcase)}%")
  }

  ALLOWED_SENDER = /\A[^@\s]*@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+\z/
  MAX_ALLOWED_SENDERS = 500

  def allowed_senders
    public_allowed_senders.to_s.split("\n")
  end

  # Anyone when the list is empty; else a listed address or @domain.
  def public_sender_allowed?(email)
    return true if allowed_senders.empty?

    email = email.to_s.strip.downcase
    domain = email.split("@", 2).last
    allowed_senders.any? { |entry| entry == email || entry == "@#{domain}" }
  end

  private

  def allowed_senders_valid
    entries = allowed_senders
    errors.add(:public_allowed_senders, :too_many_senders, count: MAX_ALLOWED_SENDERS) if entries.size > MAX_ALLOWED_SENDERS
    bad = entries.reject { |entry| entry.match?(ALLOWED_SENDER) }
    errors.add(:public_allowed_senders, :invalid_senders, entries: bad.first(5).join(", ")) if bad.any?
  end

  # A free URL name from the name; non-Latin names fall back to
  # "organization" with a number.
  def fill_slug
    return if slug.present?

    base = name.to_s.parameterize.first(50).delete_suffix("-").presence || "organization"
    candidate = base
    number = 1
    while Organization.exists?(slug: candidate)
      number += 1
      candidate = "#{base}-#{number}"
    end
    self.slug = candidate
  end
end
