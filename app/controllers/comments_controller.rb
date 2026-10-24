# Public replies and internal notes (specs/timeline.md).
class CommentsController < ApplicationController
  include TicketTimeline

  def create
    @ticket = find_visible_ticket(params[:ticket_id])
    # Only staff can write internal notes; a requester's flag is ignored.
    internal = policy.note? && params.dig(:comment, :internal) == "1"
    authorize!(internal ? policy.note? : policy.reply?)

    @comment = @ticket.add_comment(author: current_user, body: comment_params[:body], internal: internal,
                                   files: comment_params[:files] || [],
                                   status: (comment_params[:status] if current_user.staff?))
    if @comment.persisted?
      notice = internal ? t("flash.note_added") : t("flash.reply_sent")
      redirect_to ticket_path(@ticket, anchor: "event-#{@comment.event.id}"), notice: notice
    else
      prepare_timeline
      render "tickets/show", status: :unprocessable_content
    end
  end

  private

  def comment_params
    params.expect(comment: [ :body, :internal, :status, files: [] ])
  end
end
