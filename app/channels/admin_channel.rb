# Refresh signals of the admin pages (specs/admin.md "Live updates"): for
# administrators only, super or of an organization; the signal carries no
# data (specs/org-admins.md).
class AdminChannel < Turbo::StreamsChannel
  include ApplicationCable::OwnStream

  def subscribed
    stream_name = verified_stream_name_from_params
    if current_user&.admin_area? && stream_name.present? && stream_name == stream_name_for(:admin)
      stream_from stream_name
    else
      reject
    end
  end
end
