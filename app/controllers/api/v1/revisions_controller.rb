module Api
  module V1
    # Earlier versions of the request and comments, and restoring one;
    # staff only (specs/timeline.md "Editing").
    class RevisionsController < BaseController
      before_action :set_ticket

      def index
        render json: { revisions: revisions.includes(:editor).order(:created_at, :id).map { |revision| revision_json(revision) } }
      end

      def restore
        revision = revisions.find(params[:id])
        record = revision.record
        text = record.is_a?(Ticket) ? { subject: revision.subject, description: revision.body } : { body: revision.body }
        return render_invalid(record) unless record.edit(editor: current_user, **text)

        render json: { ticket: ticket_json(@ticket.reload, full: true) }
      end

      private

      def set_ticket
        @ticket = find_visible_ticket(params[:ticket_number])
        authorize!(policy_for(@ticket).see_revisions?)
      end

      def revisions
        Revision.where(record: @ticket).or(Revision.where(record_type: "Comment", record_id: @ticket.comments.select(:id)))
      end

      def revision_json(revision)
        { id: revision.id, record: revision.record_type == "Ticket" ? "description" : "comment-#{revision.record_id}",
          subject: revision.subject, body: revision.body, editor: user_json(revision.editor), created_at: time_json(revision.created_at) }
      end
    end
  end
end
