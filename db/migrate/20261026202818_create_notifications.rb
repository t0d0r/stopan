class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :ticket, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :event, foreign_key: { to_table: :ticket_events }, index: false
      t.string :kind, null: false
      t.string :status
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, %i[user_id created_at]
    add_index :notifications, %i[user_id read_at]
  end
end
