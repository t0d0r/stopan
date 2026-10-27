# SMTP and IMAP mailbox per organization (specs/organization-mail.md).
class AddMailSettingsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    change_table :organizations, bulk: true do |t|
      t.boolean :smtp_enabled, null: false, default: false
      t.string :smtp_address
      t.integer :smtp_port, null: false, default: 587
      t.string :smtp_security, null: false, default: "starttls"
      t.string :smtp_username
      t.text :smtp_password
      t.string :mail_from

      t.boolean :imap_enabled, null: false, default: false
      t.string :imap_address
      t.integer :imap_port, null: false, default: 993
      t.boolean :imap_ssl, null: false, default: true
      t.string :imap_username
      t.text :imap_password
      t.string :imap_folder, null: false, default: "INBOX"
      t.string :mailbox_address

      t.datetime :imap_last_checked_at
      t.text :imap_last_error
      t.integer :imap_messages_count, null: false, default: 0
    end
  end
end
