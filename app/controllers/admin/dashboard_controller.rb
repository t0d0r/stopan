module Admin
  class DashboardController < BaseController
    def show
      return redirect_to(org_admin_home_path) unless current_user.admin?

      @stats = {
        unsolved: Ticket.unsolved.count,
        unassigned: Ticket.unsolved.where(assignee_id: nil).count,
        done_week: Ticket.done.where(done_at: 7.days.ago..).count,
        organizations: Organization.count,
        staff: User.staff.active.count,
        requesters: User.requesters.active.count
      }
      @recent_users = User.order(created_at: :desc).limit(5)
      @shared_tickets = Ticket.shared.order(shared_at: :desc).to_a
      @busiest = Organization.joins(:tickets).merge(Ticket.unsolved).group(:id).order(Arel.sql("count(tickets.id) DESC"))
                             .limit(5).select("organizations.*, count(tickets.id) AS unsolved_count")
    end
  end
end
