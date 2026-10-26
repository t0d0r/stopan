# An in-app notification: the same message as a TicketMailer email, shown
# in the menu bar panel (specs/notifications.md "Notification panel").
class Notification < ApplicationRecord
  KINDS = %w[created replied noted assigned status_changed].freeze
  # Kinds a requester may never see, even after a role change.
  STAFF_KINDS = %w[noted].freeze
  KEEP = 200

  belongs_to :user
  belongs_to :ticket
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :event, class_name: "TicketEvent", optional: true

  validates :kind, inclusion: { in: KINDS }

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  after_create_commit :prune

  # What the user may see now: tickets still visible to them, and no
  # staff-only kinds for requesters.
  def self.visible_to(user)
    scope = where(user: user, ticket_id: Ticket.visible_to(user).select(:id))
    user.staff? ? scope : scope.where.not(kind: STAFF_KINDS)
  end

  def unread?
    read_at.nil?
  end

  private

  def prune
    old = Notification.where(user_id: user_id).newest_first.offset(KEEP).pluck(:id)
    Notification.where(id: old).delete_all if old.any?
  end
end
