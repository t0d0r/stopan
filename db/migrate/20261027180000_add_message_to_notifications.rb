# Messages from administrators are notifications without a ticket
# (specs/notifications.md "Messages from administrators").
class AddMessageToNotifications < ActiveRecord::Migration[8.1]
  def change
    change_column_null :notifications, :ticket_id, true
    add_column :notifications, :message, :text
    add_check_constraint :notifications, "ticket_id IS NOT NULL OR message IS NOT NULL", name: "notifications_ticket_or_message"
  end
end
