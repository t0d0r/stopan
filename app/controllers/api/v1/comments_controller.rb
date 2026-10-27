module Api
  module V1
    # Replies and internal notes (specs/timeline.md): the visible ones,
    # new ones with the same rules as the composer, and editing.
    class CommentsController < BaseController
      before_action :set_ticket
      before_action :set_editable_comment, only: %i[update task]

      def index
        comments = Comment.visible_to(current_user).where(ticket: @ticket).includes(:author, files_attachments: :blob)
                          .order(:created_at, :id)
        render json: { comments: comments.map { |comment| comment_json(@ticket, comment) } }
      end

      def create
        attributes = params.expect(comment: [ :body, :internal, :status, :markdown, files: [] ])
        policy = policy_for(@ticket)
        # Only staff write internal notes; a requester's flag is ignored.
        internal = policy.note? && flag(attributes[:internal])
        authorize!(internal ? policy.note? : policy.reply?)
        comment = @ticket.add_comment(author: current_user, body: attributes[:body], internal: internal,
                                      markdown: flag(attributes[:markdown]), files: attributes[:files] || [],
                                      status: (attributes[:status] if current_user.staff?))
        return render_invalid(comment) unless comment.persisted?

        render json: { comment: comment_json(@ticket, comment) }, status: :created
      end

      def update
        attributes = params.expect(comment: %i[body markdown])
        return render_invalid(@comment) if attributes.key?(:body) && !@comment.edit(editor: current_user, body: attributes[:body])

        @comment.switch_markdown(flag(attributes[:markdown])) if attributes.key?(:markdown)
        render json: { comment: comment_json(@ticket, @comment.reload) }
      end

      def task
        return render_error(:invalid, :unprocessable_content) unless @comment.toggle_task(params[:line], flag(params[:checked]), editor: current_user)

        render json: { comment: comment_json(@ticket, @comment.reload) }
      end

      private

      def set_ticket
        @ticket = find_visible_ticket(params[:ticket_number])
      end

      # Requesters never reach internal notes: Comment.visible_to hides them.
      def set_editable_comment
        @comment = Comment.visible_to(current_user).where(ticket: @ticket).find(params[:id])
        authorize!(policy_for(@ticket).edit_comment?(@comment))
      end
    end
  end
end
