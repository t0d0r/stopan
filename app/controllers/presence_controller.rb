# The presence button, panel and a ticket's viewers line, fetched again by
# staff pages after a presence signal (specs/presence.md).
class PresenceController < ApplicationController
  def show
    authorize!(current_user.staff?)
    response.headers["Cache-Control"] = "no-store"
    @ticket = Ticket.visible_to(current_user).find_by(number: params[:ticket].to_s) if params[:ticket].present?
    render formats: :turbo_stream
  end
end
