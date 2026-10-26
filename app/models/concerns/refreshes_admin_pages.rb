# Open admin pages reload when their data changes (specs/admin.md "Live
# updates"); the signal carries no content.
module RefreshesAdminPages
  extend ActiveSupport::Concern

  included do
    after_commit { RefreshesAdminPages.broadcast }
  end

  def self.broadcast
    Turbo::StreamsChannel.broadcast_refresh_later_to(:admin)
  end
end
