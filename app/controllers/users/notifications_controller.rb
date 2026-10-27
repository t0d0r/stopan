module Users
  # The staff opt-in to "new ticket" emails on the account page; no current
  # password is needed and no other field is accepted
  # (specs/notifications.md).
  class NotificationsController < ApplicationController
    def update
      authorize!(current_user.staff? && !impersonator)
      current_user.update!(notify_new_tickets: params.dig(:user, :notify_new_tickets) == "1")
      redirect_to edit_user_registration_path, notice: t("flash.notifications_saved")
    end
  end
end
