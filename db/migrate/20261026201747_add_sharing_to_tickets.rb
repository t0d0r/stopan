class AddSharingToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :share_token, :string
    add_column :tickets, :share_password_digest, :string
    add_column :tickets, :shared_at, :datetime
    add_index :tickets, :share_token, unique: true
  end
end
