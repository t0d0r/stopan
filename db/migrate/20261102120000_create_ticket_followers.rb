# Staff followers and Cc of a ticket (specs/followers.md).
class CreateTicketFollowers < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_followers do |t|
      t.references :ticket, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.references :added_by, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
      t.timestamps
    end
    add_index :ticket_followers, %i[ticket_id user_id], unique: true
  end
end
