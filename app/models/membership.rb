# A user belongs to an organization. Requesters open tickets only for
# organizations they belong to, and see them only while they still do.
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  validates :user_id, uniqueness: { scope: :organization_id }
end
