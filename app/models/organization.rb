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

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :notes, length: { maximum: 5_000 }
  validates :slug, presence: true, length: { minimum: 2 }, format: { with: SLUG }, uniqueness: true
  validates :public_intro, length: { maximum: 1_000 }

  before_validation :fill_slug, on: :create

  scope :with_public_form, -> { where(public_form: true) }

  scope :ordered, -> { order(Arel.sql("lower(organizations.name)")) }
  scope :search, ->(query) {
    where("ulower(organizations.name) LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(query.to_s.strip.downcase)}%")
  }

  private

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
