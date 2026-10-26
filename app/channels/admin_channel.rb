# Refresh signals of the admin pages (specs/admin.md "Live updates"): for
# administrators only.
class AdminChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    stream_name = verified_stream_name_from_params
    if current_user&.admin? && stream_name.present? && stream_name == stream_name_for(:admin)
      stream_from stream_name
    else
      reject
    end
  end
end
