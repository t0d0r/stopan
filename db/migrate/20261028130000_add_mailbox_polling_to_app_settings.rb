# Automatic fetching from the organizations' mailboxes, set on
# /admin/settings (specs/organization-mail.md "Fetching").
class AddMailboxPollingToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :mailbox_polling, :boolean, null: false, default: false
    add_column :app_settings, :mailbox_poll_seconds, :integer, null: false, default: 120
  end
end
