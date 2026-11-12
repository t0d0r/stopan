# HTTP calls to another system on a new ticket or public reply, per
# organization (specs/webhooks.md).
class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :url, null: false
      t.text :secret, null: false
      t.string :events, null: false
      t.boolean :active, null: false, default: true
      t.integer :failures, null: false, default: 0
      t.integer :last_status
      t.string :last_error
      t.datetime :last_sent_at
      t.timestamps
    end
  end
end
