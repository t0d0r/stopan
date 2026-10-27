# Bulk actions of the queue and search results (specs/queues.md "Bulk
# actions"): one change for the selected tickets, or for every ticket of
# the list, then back to the list with what happened.
class TicketBulkController < ApplicationController
  SKIPPED_SHOWN = 10

  def update
    authorize!(current_user.staff?)
    bulk = TicketBulkUpdate.new(user: current_user, changes: params.fetch(:changes, {}).permit(:status, :priority, :assignee),
                                numbers: params[:numbers], list: (list_params if params[:scope] == "list"),
                                delete: params[:delete] == "1")
    return redirect_to(back_path, alert: t("flash.bulk_nothing_chosen")) unless bulk.changes?
    return redirect_to(back_path, alert: t("flash.bulk_nothing_selected")) if bulk.tickets.empty?

    bulk.run
    flash_result(bulk)
    redirect_to back_path
  end

  private

  def list_params
    params.permit(list: TicketBulkUpdate::LIST_FILTERS)[:list] || {}
  end

  # Only back to a ticket list.
  def back_path
    path = params[:return_to].to_s
    path.match?(%r{\A/tickets(\?|\z)}) ? path : tickets_path
  end

  def flash_result(bulk)
    flash[:notice] = t(bulk.delete? ? "flash.bulk_deleted" : "flash.bulk_updated", count: bulk.updated.size)
    return if bulk.skipped.empty?

    shown = bulk.skipped.first(SKIPPED_SHOWN).map { |skip| "#{skip.ticket.reference} (#{skip.reason})" }
    flash[:alert] = t("flash.bulk_skipped", count: bulk.skipped.size, tickets: shown.join(", "))
  end
end
