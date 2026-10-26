class AddNotificationSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :locale, :string
    add_column :users, :notify_new_tickets, :boolean, null: false, default: false
  end
end
