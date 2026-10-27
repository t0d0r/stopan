class Organization < ApplicationRecord
  include RefreshesAdminPages
  include MailSettings

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :tickets, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :notes, length: { maximum: 5_000 }

  scope :ordered, -> { order(Arel.sql("lower(organizations.name)")) }
  scope :search, ->(query) {
    where("ulower(organizations.name) LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(query.to_s.strip.downcase)}%")
  }
end
