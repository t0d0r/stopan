# One entry of a ticket's audit history. Rows are only ever inserted
# (specs/timeline.md); `internal` rows are hidden from requesters.
class TicketEvent < ApplicationRecord
  ACTIONS = %w[created replied noted status_changed priority_changed assignee_changed shared unshared stage_changed deleted restored].freeze

  belongs_to :ticket
  belongs_to :actor, class_name: "User", optional: true, inverse_of: :ticket_events
  belongs_to :comment, optional: true

  validates :action, inclusion: { in: ACTIONS }

  after_create { TicketNotifier.collect(self) }
  # Open ticket pages reload (specs/timeline.md), and public changes also
  # reload an open shared page (specs/sharing.md).
  after_create_commit do
    ticket.refresh_pages(internal: internal?)
    ticket.refresh_shared_page unless internal?
  end

  def self.visible_to(user)
    return none unless user
    return all if user.staff?

    where(internal: false)
  end

  def readonly?
    persisted?
  end

  def comment_event?
    comment_id.present?
  end
end
