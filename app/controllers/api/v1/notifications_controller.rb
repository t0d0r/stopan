module Api
  module V1
    # The user's own notifications (specs/notifications.md), 50 a page.
    class NotificationsController < BaseController
      PER_PAGE = 50

      def index
        page = [ params[:page].to_i, 1 ].max
        scope = Notification.visible_to(current_user)
        notifications = scope.newest_first.includes(:actor, :ticket).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
        render json: { notifications: notifications.map { |notification| notification_json(notification) },
                       page: page, total_count: scope.count, unread_count: scope.unread.count }
      end

      def read
        notification = Notification.visible_to(current_user).find(params[:id])
        Notification.mark_read(current_user, Notification.where(id: notification.id))
        render json: { notification: notification_json(notification.reload) }
      end

      def read_all
        Notification.mark_read(current_user)
        head :no_content
      end
    end
  end
end
