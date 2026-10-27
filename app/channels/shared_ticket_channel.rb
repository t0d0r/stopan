# Refresh signals and the viewer count of an open shared page
# (specs/sharing.md): no sign-in, only the current link's stream, and each
# subscription counts as one viewer until it ends.
class SharedTicketChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    ticket = Ticket.shared.find_by(number: params[:ticket].to_s)
    stream_name = verified_stream_name_from_params
    if ticket && stream_name.present? && stream_name == stream_name_for(ticket.share_stream)
      stream_from stream_name
      @ticket = ticket
      @digest = ticket.share_digest
      ShareViewers.join(@ticket, @digest)
    else
      reject
    end
  end

  def unsubscribed
    ShareViewers.leave(@ticket, @digest) if @digest
  end
end
