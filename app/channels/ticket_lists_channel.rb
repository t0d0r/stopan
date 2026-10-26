# Refresh signals of the ticket lists (specs/queues.md "Live updates"): the
# staff queue only for staff, a requester's list only for its owner.
class TicketListsChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    stream_name = verified_stream_name_from_params
    if current_user && stream_name.present? && stream_name == stream_name_for(Ticket.list_stream(current_user))
      stream_from stream_name
    else
      reject
    end
  end
end
