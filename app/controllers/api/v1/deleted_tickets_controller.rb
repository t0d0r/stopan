module Api
  module V1
    # Deleted tickets for administrators, and restoring one
    # (specs/tickets.md "Deleting").
    class DeletedTicketsController < BaseController
      before_action :require_admin!

      def index
        tickets = Ticket.deleted.includes(:organization, :requester, :assignee, :stage, :deleted_by)
                        .order(deleted_at: :desc, id: :desc).limit(500)
        render json: { tickets: tickets.map { |ticket| ticket_json(ticket).merge(deleted_at: time_json(ticket.deleted_at), deleted_by: user_json(ticket.deleted_by)) } }
      end

      def restore
        ticket = Ticket.deleted.find_by!(number: params[:number].to_s)
        ticket.restore!(actor: current_user)
        render json: { ticket: ticket_json(ticket.reload, full: true) }
      end
    end
  end
end
