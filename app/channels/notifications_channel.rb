# The notification panel's refresh signal (specs/notifications.md): only the
# signed-in owner of a [user, :notifications] stream may subscribe to it.
class NotificationsChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    stream_name = verified_stream_name_from_params
    if current_user && stream_name.present? && stream_name == stream_name_for([ current_user, :notifications ])
      stream_from stream_name
    else
      reject
    end
  end
end
