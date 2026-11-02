# The composer's "Email the requester" toggle (specs/notifications.md
# "Emails to the requester"): saves at once, for staff who may update the
# ticket. Without JavaScript the toggle comes with the reply instead
# (CommentsController).
class RequesterMailsController < ApplicationController
  def update
    ticket = find_visible_ticket(params[:ticket_id])
    authorize!(TicketPolicy.new(current_user, ticket).update?)

    ticket.switch_requester_mail!(params[:email_requester] == "1", actor: current_user)
    head :no_content
  end
end
