# The user's in-app notifications (specs/notifications.md "Notification
# panel"). Only their own, and only for tickets they can still see.
class NotificationsController < ApplicationController
  PER_PAGE = 50

  def index
    @page = [ params[:page].to_i, 1 ].max
    scope = Notification.visible_to(current_user)
    @total = scope.count
    @notifications = scope.newest_first.includes(:actor, :ticket).offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @more = @total > @page * PER_PAGE
  end

  # The bell and panel alone, fetched again after a live signal.
  def panel
    response.headers["Cache-Control"] = "no-store"
    render partial: "partials/notifications"
  end

  # Marks the notification read and opens the ticket at its event, or shows
  # a message from an administrator in full.
  def show
    @notification = Notification.visible_to(current_user).find(params[:id])
    Notification.mark_read(current_user, Notification.where(id: @notification.id))
    return if @notification.message?

    redirect_to ticket_path(@notification.ticket, anchor: ("event-#{@notification.event_id}" if @notification.event_id))
  end

  def read_all
    Notification.mark_read(current_user)
    redirect_back_or_to notifications_path, allow_other_host: false, notice: t("flash.notifications_read")
  end
end
