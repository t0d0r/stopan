# The notification panel's refresh signal (specs/notifications.md): only the
# signed-in owner of a [user, :notifications] stream may subscribe to it.
class NotificationsChannel < Turbo::StreamsChannel
  def subscribed
    stream_name = verified_stream_name_from_params
    if current_user && stream_name.present? && stream_name == own_stream_name
      stream_from stream_name
    else
      reject
    end
  end

  private

  # Turbo keeps the name builder private; signing and verifying gives it.
  def own_stream_name
    self.class.verified_stream_name(self.class.signed_stream_name([ current_user, :notifications ]))
  end
end
