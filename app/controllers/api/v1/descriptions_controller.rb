module Api
  module V1
    # Editing the request's subject and description, the Markdown switch
    # and task ticks (specs/timeline.md "Editing", specs/markdown.md).
    class DescriptionsController < BaseController
      before_action :set_ticket

      def update
        text = params.expect(ticket: %i[subject description markdown])
        edits = text.slice(:subject, :description).to_h.symbolize_keys
        return render_invalid(@ticket) if edits.any? && !@ticket.edit(editor: current_user, **edits)

        @ticket.switch_markdown(flag(text[:markdown])) if text.key?(:markdown)
        render json: { ticket: ticket_json(@ticket.reload, full: true) }
      end

      def task
        return render_error(:invalid, :unprocessable_content) unless @ticket.toggle_task(params[:line], flag(params[:checked]), editor: current_user)

        render json: { ticket: ticket_json(@ticket.reload, full: true) }
      end

      private

      def set_ticket
        @ticket = find_visible_ticket(params[:ticket_number])
        authorize!(policy_for(@ticket).edit_description?)
      end
    end
  end
end
