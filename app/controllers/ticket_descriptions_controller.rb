# Editing the request's subject and description (specs/timeline.md
# "Editing"). The previous text is kept as a revision.
class TicketDescriptionsController < ApplicationController
  include TicketTimeline

  before_action :set_ticket

  def edit
  end

  def update
    if @ticket.edit(editor: current_user, **description_params.to_h.symbolize_keys)
      redirect_to_ticket @ticket, anchor: "description", notice: t("flash.request_updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Ticks a Markdown task item (specs/markdown.md "Task lists").
  def task
    head(@ticket.toggle_task(params[:line], params[:checked] == "1", editor: current_user) ? :no_content : :unprocessable_content)
  end

  # Markdown on or off (specs/markdown.md); not an edit.
  def markdown
    @ticket.switch_markdown(params[:markdown] == "1")
    redirect_to_ticket @ticket, anchor: "description"
  end

  private

  def set_ticket
    @ticket = find_visible_ticket(params[:ticket_id])
    authorize!(policy.edit_description?)
  end

  def description_params
    params.expect(ticket: %i[subject description])
  end
end
