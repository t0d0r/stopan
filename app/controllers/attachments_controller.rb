# Downloads a file of a ticket or of one of its comments, after the same
# visibility checks as the ticket page (specs/attachments.md). Files are
# never shown inline.
class AttachmentsController < ApplicationController
  def show
    ticket = find_visible_ticket(params[:ticket_id])
    comments = Comment.visible_to(current_user).where(ticket: ticket).select(:id)
    attachment = ActiveStorage::Attachment.where(name: "files", record_type: "Ticket", record_id: ticket.id)
                   .or(ActiveStorage::Attachment.where(name: "files", record_type: "Comment", record_id: comments))
                   .find(params[:id])
    send_blob(attachment.blob)
  end

  private

  # The Disk service has a file on disk, which Rack sends in chunks (and a
  # proxy can take over with X-Sendfile); other services are downloaded.
  def send_blob(blob)
    options = { filename: blob.filename.to_s, type: blob.content_type, disposition: "attachment" }
    if blob.service.respond_to?(:path_for)
      send_file blob.service.path_for(blob.key), **options
    else
      send_data blob.download, **options
    end
  end
end
