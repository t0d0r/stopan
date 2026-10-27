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
  after_create_commit { self.class.broadcast_changed(user) }

  # What the user may see now: tickets still visible to them, and no
  # staff-only kinds for requesters.
  def self.visible_to(user)
    scope = where(user: user, ticket_id: Ticket.visible_to(user).select(:id))
    user.staff? ? scope : scope.where.not(kind: STAFF_KINDS)
  end

  # Tells the user's open pages to fetch the panel again; the signal carries
  # no content (specs/notifications.md "Live updates of the panel"), only
  # the Turbo request id, so the tab that caused it does not reload twice.
  def self.broadcast_changed(user)
    Turbo::StreamsChannel.broadcast_action_later_to(user, :notifications, action: "notifications_refresh",
                                                                          target: "notifications",
                                                                          attributes: { "request-id": Turbo.current_request_id }.compact)
  end

  # Marks the user's unread notifications in scope read and tells their
  # other pages.
  def self.mark_read(user, scope = all)
    broadcast_changed(user) if scope.where(user: user).unread.update_all(read_at: Time.current).positive?
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
