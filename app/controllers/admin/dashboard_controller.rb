module Admin
  class DashboardController < BaseController
    def show
      @stats = {
        unsolved: Ticket.unsolved.count,
        unassigned: Ticket.unsolved.where(assignee_id: nil).count,
        solved_week: Ticket.solved.where(resolved_at: 7.days.ago..).or(Ticket.where(closed_at: 7.days.ago..)).count,
        organizations: Organization.count,
        staff: User.staff.active.count,
        requesters: User.requesters.active.count
      }
      @recent_users = User.order(created_at: :desc).limit(5)
      @busiest = Organization.joins(:tickets).merge(Ticket.unsolved).group(:id).order(Arel.sql("count(tickets.id) DESC"))
                             .limit(5).select("organizations.*, count(tickets.id) AS unsolved_count")
    end
  end
end
