# What the reader sees of who is online (specs/presence.md): staff by name,
# requesters as a number within the reader's organizations, and the other
# people on a ticket.
module PresenceHelper
  PresenceView = Data.define(:staff, :requester_count) do
    def count = staff.size + requester_count
  end

  def presence_view
    @presence_view ||= begin
      users = User.where(id: Presence.user_ids | [ current_user.id ], deactivated_at: nil)
      staff = users.select(&:staff?).sort_by { |user| [ user == current_user ? 0 : 1, user.display_name.downcase ] }
      requesters = users.where(role: "requester")
      requesters = requesters.joins(:memberships).where(memberships: { organization_id: current_user.organization_ids }) unless current_user.admin?
      PresenceView.new(staff: staff, requester_count: requesters.distinct.count)
    end
  end

  # The others who have the ticket open, staff first.
  def ticket_viewers(ticket)
    User.where(id: Presence.viewer_ids(ticket) - [ current_user.id ], deactivated_at: nil)
        .sort_by { |user| [ user.staff? ? 0 : 1, user.display_name.downcase ] }
  end
end
