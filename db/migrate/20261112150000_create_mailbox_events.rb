# What became of each message a mailbox took in (specs/status.md "Mail in").
class CreateMailboxEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :mailbox_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :result, null: false
      t.string :reason
      t.string :sender
      t.string :subject
      t.references :ticket, foreign_key: { on_delete: :nullify }
      t.datetime :created_at, null: false
    end
    add_index :mailbox_events, %i[organization_id id]
  end
end
