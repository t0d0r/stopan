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
      # Shared tickets of the administrator's own organizations (specs/sharing.md "Admin").
      @shared_tickets = Ticket.visible_to(current_user).shared.order(shared_at: :desc).to_a
      @busiest = Organization.joins(:tickets).merge(Ticket.unsolved).group(:id).order(Arel.sql("count(tickets.id) DESC"))
                             .limit(5).select("organizations.*, count(tickets.id) AS unsolved_count")
      # specs/admin.md "Google accounts that need reconnecting".
      @needs_reconnect = Organization.where(mail_auth: "google").joins(:mail_connection)
                                     .merge(MailConnection.where(status: "needs_reconnect"))
                                     .includes(:mail_connection).order(:name).to_a
      # specs/status.md "Also on the dashboard".
      @attention = { mailboxes: Organization.where(imap_enabled: true).where.not(imap_last_error: [ nil, "" ]).count,
                     jobs: QueueStatus.current&.counts&.fetch(:failed) || 0,
                     webhooks: Webhook.where(active: false).where("failures > 0").count }.select { |_, count| count.positive? }
    end
  end
end
