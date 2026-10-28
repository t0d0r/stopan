# Counts each open page of a signed-in user as online (specs/presence.md):
# only the reader's own presence stream, and the ticket only when they may
# see it. Staff pages also get the presence signal on it.
class PresenceChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    stream_name = verified_stream_name_from_params
    if current_user && stream_name.present? && stream_name == stream_name_for(Presence.stream(current_user))
      stream_from stream_name
      ticket = Ticket.visible_to(current_user).find_by(number: params[:ticket].to_s) if params[:ticket].present?
      @presence_key = SecureRandom.uuid
      Presence.join(@presence_key, current_user, ticket)
    else
      reject
    end
  end

  def unsubscribed
    Presence.leave(@presence_key) if @presence_key
  end
end
