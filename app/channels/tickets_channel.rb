# Refresh signals of an open ticket page (specs/timeline.md "Live
# updates"): only for a signed-in user who can see the ticket now, and the
# staff stream only for staff.
class TicketsChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    ticket = Ticket.visible_to(current_user).find_by(number: params[:ticket].to_s) if current_user
    stream_name = verified_stream_name_from_params
    if ticket && stream_name.present? && stream_name == stream_name_for(ticket.page_stream(current_user))
      stream_from stream_name
    else
      reject
    end
  end
end
