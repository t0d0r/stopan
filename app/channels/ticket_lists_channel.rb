# Refresh signals of the ticket lists (specs/queues.md "Live updates"): the
# staff queue only for staff, a requester's list only for its owner, an
# organization's list only for its current members.
class TicketListsChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    stream_name = verified_stream_name_from_params
    allowed = current_user && Ticket.list_streams(current_user).map { |streamables| stream_name_for(streamables) }
    if stream_name.present? && allowed&.include?(stream_name)
      stream_from stream_name
    else
      reject
    end
  end
end
