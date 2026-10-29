module Admin
  # Deleted tickets for administrators to review and bring back
  # (specs/tickets.md "Deleting"); organization administrators see their
  # organizations' only (specs/org-admins.md).
  class DeletedTicketsController < BaseController
    PER_PAGE = 50

    def index
      @page = [ params[:page].to_i, 1 ].max
      scope = admin_scope.deleted_tickets
      @total = scope.count
      @tickets = scope.includes(:organization, :requester, :deleted_by).order(deleted_at: :desc, id: :desc)
                      .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    end

    def restore
      ticket = admin_scope.deleted_tickets.find_by!(number: params[:number].to_s)
      ticket.restore!(actor: current_user)
      redirect_to ticket_path(ticket), notice: t("flash.ticket_restored", reference: ticket.reference)
    end
  end
end
