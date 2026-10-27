module Api
  module V1
    # A file of a ticket or of one of its visible comments, as a download
    # (specs/attachments.md).
    class AttachmentsController < BaseController
      include FileSending

      def show
        ticket = find_visible_ticket(params[:ticket_number])
        comments = Comment.visible_to(current_user).where(ticket: ticket).select(:id)
        attachment = ActiveStorage::Attachment.where(name: "files", record_type: "Ticket", record_id: ticket.id)
                                              .or(ActiveStorage::Attachment.where(name: "files", record_type: "Comment", record_id: comments))
                                              .find(params[:id])
        send_blob(attachment.blob)
      end
    end
  end
end
