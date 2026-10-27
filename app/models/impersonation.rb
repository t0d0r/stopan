# An administrator acting as another user (specs/admin.md "Impersonation").
# Only ever inserted, then ended.
class Impersonation < ApplicationRecord
  belongs_to :admin, class_name: "User"
  belongs_to :user

  scope :newest_first, -> { order(started_at: :desc, id: :desc) }

  # Agents and requesters that are active; never admins or oneself.
  def self.allowed?(admin, user)
    admin&.admin? && !admin.deactivated? && user && user != admin && !user.admin? && !user.deactivated?
  end
end
