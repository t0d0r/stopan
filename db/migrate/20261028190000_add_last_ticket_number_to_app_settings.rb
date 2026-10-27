# The highest ticket number ever given, so numbers of flushed tickets are
# never reused (specs/admin.md "Flush all tickets of an organization").
class AddLastTicketNumberToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :last_ticket_number, :integer, null: false, default: 0
  end
end
