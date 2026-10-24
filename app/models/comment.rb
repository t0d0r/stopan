# A public reply or an internal note on a ticket (specs/timeline.md).
class Comment < ApplicationRecord
  include Attachable

  belongs_to :ticket, touch: true
  belongs_to :author, class_name: "User", inverse_of: :comments
  has_one :event, class_name: "TicketEvent", dependent: :restrict_with_error

  normalizes :body, with: ->(body) { body.strip }

  validates :body, presence: true, length: { maximum: 20_000 }
  validate :only_staff_write_internal_notes
  validate :ticket_accepts_replies, on: :create

  after_create :record_event

  def self.visible_to(user)
    return none unless user
    return all if user.staff?

    where(internal: false)
  end

  # Comments are part of the audit history and never change.
  def readonly?
    persisted?
  end

  private

  def only_staff_write_internal_notes
    errors.add(:internal, :staff_only) if internal? && !author&.staff?
  end

  def ticket_accepts_replies
    errors.add(:base, :ticket_closed) if !internal? && ticket&.closed?
  end

  def record_event
    ticket.events.create!(action: internal? ? "noted" : "replied", actor: author, comment: self, internal: internal?)
  end
end
