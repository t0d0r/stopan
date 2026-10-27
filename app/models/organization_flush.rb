# Removes every ticket of an organization for good, with all that hangs on
# them, and nothing else (specs/admin.md "Flush all tickets of an
# organization"): settings, members and users stay.
class OrganizationFlush
  attr_reader :organization, :actor, :removed

  def initialize(organization, actor:)
    @organization = organization
    @actor = actor
    @removed = 0
  end

  # The exact name, spaces around it ignored, case-sensitive.
  def confirmed?(name)
    name.to_s.strip == organization.name
  end

  def ticket_count
    organization.tickets.count
  end

  def run
    ticket_ids = organization.tickets.pluck(:id)
    return self if ticket_ids.empty?

    comment_ids = Comment.where(ticket_id: ticket_ids).pluck(:id)
    attachments = ActiveStorage::Attachment.where(record_type: "Ticket", record_id: ticket_ids)
                                           .or(ActiveStorage::Attachment.where(record_type: "Comment", record_id: comment_ids))
    blob_ids = attachments.pluck(:blob_id)
    ApplicationRecord.transaction do
      remember_highest_number
      Notification.where(ticket_id: ticket_ids).delete_all
      TicketEvent.where(ticket_id: ticket_ids).delete_all
      Translation.where(translatable_type: "Ticket", translatable_id: ticket_ids)
                 .or(Translation.where(translatable_type: "Comment", translatable_id: comment_ids)).delete_all
      Revision.where(record_type: "Ticket", record_id: ticket_ids)
              .or(Revision.where(record_type: "Comment", record_id: comment_ids)).delete_all
      attachments.delete_all
      Comment.where(id: comment_ids).delete_all
      @removed = Ticket.where(id: ticket_ids).delete_all
    end
    # Stored files go once nothing points at them any more.
    ActiveStorage::Blob.where(id: blob_ids).find_each(&:purge_later)
    Rails.logger.info("Organization #{organization.id}: #{@removed} tickets flushed by user #{actor.id}")
    RefreshesAdminPages.broadcast
    Turbo::StreamsChannel.broadcast_refresh_later_to(:queue, :staff)
    self
  end

  private

  def remember_highest_number
    setting = AppSetting.current
    highest = [ setting.last_ticket_number, Ticket.maximum(:number).to_i ].max
    setting.update_column(:last_ticket_number, highest)
  end
end
