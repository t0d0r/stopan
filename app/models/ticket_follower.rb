# A staff follower or a person in Cc on a ticket (specs/followers.md): the
# kind follows the user's role.
class TicketFollower < ApplicationRecord
  belongs_to :ticket
  belongs_to :user
  belongs_to :added_by, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :ticket_id }
  validate :user_may_follow

  scope :staff, -> { joins(:user).merge(User.staff) }
  scope :cc, -> { joins(:user).merge(User.requesters) }

  def cc?
    !user.staff?
  end

  private

  def user_may_follow
    return unless user && ticket

    if user.deactivated? then errors.add(:user, :deactivated)
    elsif !user.member_of?(ticket.organization) then errors.add(:user, :not_a_member)
    elsif user.id == ticket.requester_id then errors.add(:user, :requester)
    end
  end
end
