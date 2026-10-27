module Api
  module V1
    # Tickets (specs/api.md): the list, one ticket with its timeline, new
    # tickets, staff changes and the requester's "Mark as done", with the
    # rules of the pages (TicketsController, specs/roles.md).
    class TicketsController < BaseController
      before_action :set_ticket, only: %i[show update resolve destroy]

      def index
        filter = TicketFilter.new(current_user, params)
        tickets = filter.tickets
        render json: { tickets: tickets.map { |ticket| ticket_json(ticket) }, view: filter.view, page: filter.page,
                       total_pages: filter.total_pages, total_count: filter.total_count }
      end

      def show
        render json: { ticket: ticket_json(@ticket, full: true) }
      end

      def create
        ticket = Ticket.new(ticket_params)
        ticket.markdown = flag(ticket_params[:markdown])
        ticket.actor = current_user
        unless current_user.staff?
          ticket.requester = current_user
          ticket.organization ||= current_user.organizations.first if current_user.organizations.one?
        end
        # Agents create tickets only in their own organizations (roles.md).
        if current_user.agent? && ticket.organization && !current_user.member_of?(ticket.organization)
          ticket.errors.add(:organization, :not_yours)
          return render_invalid(ticket)
        end
        authorize!(TicketPolicy.new(current_user, ticket).create?)
        return render_invalid(ticket) unless ticket.save

        render json: { ticket: ticket_json(ticket, full: true) }, status: :created
      end

      # Staff change status, priority, assignee and stage.
      def update
        authorize!(policy_for(@ticket).update?)
        changes = params.expect(ticket: %i[status priority assignee_id stage_id])
        return render_invalid(@ticket) unless @ticket.apply_changes(changes, actor: current_user)

        render json: { ticket: ticket_json(@ticket.reload, full: true) }
      end

      def resolve
        authorize!(policy_for(@ticket).resolve?)
        @ticket.apply_changes!({ status: Ticket::DONE }, actor: current_user)
        render json: { ticket: ticket_json(@ticket.reload, full: true) }
      end

      # Soft delete (specs/tickets.md "Deleting").
      def destroy
        authorize!(policy_for(@ticket).delete?)
        @ticket.soft_delete!(actor: current_user)
        head :no_content
      end

      private

      def set_ticket
        @ticket = find_visible_ticket(params[:number])
      end

      # Requesters choose only the text, the organization and files.
      def ticket_params
        @ticket_params ||= begin
          fields = %i[subject description markdown organization_id]
          fields += %i[requester_id priority assignee_id] if current_user.staff?
          params.expect(ticket: [ *fields, files: [] ])
        end
      end
    end
  end
end
