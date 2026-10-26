# Downloads a file of a ticket or of one of its comments, after the same
# visibility checks as the ticket page (specs/attachments.md). Files are
# never shown inline.
class AttachmentsController < ApplicationController
  include FileSending

  def show
    ticket = find_visible_ticket(params[:ticket_id])
    comments = Comment.visible_to(current_user).where(ticket: ticket).select(:id)
    attachment = ActiveStorage::Attachment.where(name: "files", record_type: "Ticket", record_id: ticket.id)
                   .or(ActiveStorage::Attachment.where(name: "files", record_type: "Comment", record_id: comments))
                   .find(params[:id])
    send_blob(attachment.blob)
  end
end
