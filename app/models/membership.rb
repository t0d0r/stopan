# A user belongs to an organization. Requesters open tickets only for
# organizations they belong to, and see them only while they still do.
class Membership < ApplicationRecord
  include RefreshesAdminPages

  belongs_to :user
  belongs_to :organization

  validates :user_id, uniqueness: { scope: :organization_id }
  # Only agents can be organization administrators (specs/org-admins.md).
  validate :admin_only_for_agents

  scope :administering, -> { where(admin: true) }

  private

  def admin_only_for_agents
    errors.add(:admin, :agents_only) if admin? && !user&.agent?
  end
end
