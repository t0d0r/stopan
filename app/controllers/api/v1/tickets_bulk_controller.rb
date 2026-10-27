module Api
  module V1
    # Bulk changes for staff (specs/queues.md "Bulk actions"): selected
    # numbers or every ticket of a list, one by one with the usual checks.
    class TicketsBulkController < BaseController
      def update
        require_staff!
        list = params.permit(list: TicketBulkUpdate::LIST_FILTERS)[:list] if params[:scope] == "list"
        bulk = TicketBulkUpdate.new(user: current_user, changes: params.fetch(:changes, {}).permit(:status, :priority, :assignee),
                                    numbers: params[:numbers], list: list || ({} if params[:scope] == "list"))
        return render_error(:invalid, :unprocessable_content, message: I18n.t("flash.bulk_nothing_chosen")) unless bulk.changes?

        bulk.run
        render json: { updated: bulk.updated.map(&:number), unchanged: bulk.unchanged.map(&:number),
                       skipped: bulk.skipped.map { |skip| { number: skip.ticket.number, reason: skip.reason } } }
      end
    end
  end
end
