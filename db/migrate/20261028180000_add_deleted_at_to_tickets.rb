# Soft delete of tickets (specs/tickets.md "Deleting"): nothing is removed,
# so the audit history stays complete.
class AddDeletedAtToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :deleted_at, :datetime
    add_reference :tickets, :deleted_by, foreign_key: { to_table: :users }
    add_index :tickets, :deleted_at
  end
end
