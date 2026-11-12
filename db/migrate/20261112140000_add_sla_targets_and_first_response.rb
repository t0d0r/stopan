# SLA targets per priority, and when a ticket got its first public reply
# from staff (specs/sla.md).
class AddSlaTargetsAndFirstResponse < ActiveRecord::Migration[8.1]
  def up
    add_column :app_settings, :sla_targets, :json, null: false, default: {}
    add_column :tickets, :first_response_at, :datetime
    execute <<~SQL.squish
      UPDATE tickets SET first_response_at = (
        SELECT MIN(comments.created_at) FROM comments JOIN users ON users.id = comments.author_id
        WHERE comments.ticket_id = tickets.id AND comments.internal = 0 AND users.role IN ('agent', 'admin')
      )
    SQL
  end

  def down
    remove_column :tickets, :first_response_at
    remove_column :app_settings, :sla_targets
  end
end
