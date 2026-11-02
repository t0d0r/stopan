# The reason or error of a mail event (specs/followers.md "Notifications
# and emails").
class AddDetailToTicketEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :ticket_events, :detail, :string
  end
end
