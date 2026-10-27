# Public replies and internal notes (specs/timeline.md), and editing
# their text ("Editing").
class CommentsController < ApplicationController
  include TicketTimeline

  before_action :set_editable_comment, only: %i[edit update markdown]

  def create
    @ticket = find_visible_ticket(params[:ticket_id])
    # Only staff can write internal notes; a requester's flag is ignored.
    internal = policy.note? && params.dig(:comment, :internal) == "1"
    authorize!(internal ? policy.note? : policy.reply?)

    @comment = @ticket.add_comment(author: current_user, body: comment_params[:body], internal: internal,
                                   markdown: comment_params[:markdown] == "1",
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

  def edit
  end

  def update
    if @comment.edit(editor: current_user, body: params.expect(comment: [ :body ])[:body])
      redirect_to_ticket @ticket, anchor: "event-#{@comment.event.id}",
                                  notice: @comment.internal? ? t("flash.note_updated") : t("flash.reply_updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Markdown on or off (specs/markdown.md); not an edit.
  def markdown
    @comment.switch_markdown(params[:markdown] == "1")
    redirect_to_ticket @ticket, anchor: "event-#{@comment.event.id}"
  end

  private

  # Requesters never reach internal notes: Comment.visible_to hides them.
  def set_editable_comment
    @ticket = find_visible_ticket(params[:ticket_id])
    @comment = Comment.visible_to(current_user).where(ticket: @ticket).find(params[:id])
    authorize!(policy.edit_comment?(@comment))
  end

  def comment_params
    params.expect(comment: [ :body, :internal, :status, :markdown, files: [] ])
  end
end
