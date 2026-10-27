# Restores an earlier version of a request or comment (specs/timeline.md
# "Editing"). Staff only; a restore is an ordinary edit, so the current
# text becomes another earlier version.
class RevisionsController < ApplicationController
  include TicketTimeline

  def restore
    @ticket = find_visible_ticket(params[:ticket_id])
    authorize!(policy.see_revisions?)
    revision = Revision.where(record: @ticket)
                       .or(Revision.where(record_type: "Comment", record_id: @ticket.comments.select(:id)))
                       .find(params[:id])
    record = revision.record
    text = record.is_a?(Ticket) ? { subject: revision.subject, description: revision.body } : { body: revision.body }
    anchor = record.is_a?(Ticket) ? "description" : "event-#{record.event.id}"
    if record.edit(editor: current_user, **text)
      redirect_to_ticket @ticket, anchor: anchor, notice: t("flash.revision_restored")
    else
      redirect_to_ticket @ticket, anchor: anchor, alert: record.errors.full_messages.to_sentence
    end
  end
end
