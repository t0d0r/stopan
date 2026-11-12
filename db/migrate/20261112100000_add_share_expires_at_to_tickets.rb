# When a ticket's share link stops on its own; NULL is never
# (specs/sharing.md "Expiry").
class AddShareExpiresAtToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :share_expires_at, :datetime
  end
end
