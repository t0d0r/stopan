# One finished status, "done", instead of "resolved" and "closed"
# (specs/tickets.md "One Done status"). Plain SQL, so the migration does
# not depend on the models as they are now.
class MergeResolvedAndClosedIntoDone < ActiveRecord::Migration[8.1]
  OLD = "('resolved', 'closed')"

  def up
    execute <<~SQL
      UPDATE tickets
      SET status = 'done',
          resolved_at = COALESCE(MAX(COALESCE(closed_at, resolved_at), COALESCE(resolved_at, closed_at)), updated_at)
      WHERE status IN #{OLD}
    SQL
    rename_column :tickets, :resolved_at, :done_at
    remove_column :tickets, :closed_at, :datetime

    # A change from one old status to the other would read "Done to Done".
    same = "SELECT id FROM ticket_events WHERE action = 'status_changed' AND from_value IN #{OLD} AND to_value IN #{OLD}"
    execute "UPDATE notifications SET event_id = NULL WHERE event_id IN (#{same})"
    execute "DELETE FROM ticket_events WHERE id IN (#{same})"
    %w[from_value to_value].each do |column|
      execute "UPDATE ticket_events SET #{column} = 'done' WHERE action = 'status_changed' AND #{column} IN #{OLD}"
    end
    execute "UPDATE notifications SET status = 'done' WHERE status IN #{OLD}"

    merge_stages
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "done tickets do not say whether they were resolved or closed"
  end

  private

  # Resolved stages keep their order, closed ones follow; a closed stage
  # with a resolved stage's name is merged into it.
  def merge_stages
    offset = select_value("SELECT COALESCE(MAX(position), -1) + 1 FROM stages WHERE status = 'resolved'").to_i
    select_rows("SELECT id, name FROM stages WHERE status = 'closed' ORDER BY position, id").each do |id, name|
      twin = select_value("SELECT id FROM stages WHERE status = 'resolved' AND lower(name) = lower(#{quote(name)})")
      if twin
        execute "UPDATE tickets SET stage_id = #{twin.to_i} WHERE stage_id = #{id.to_i}"
        execute "DELETE FROM stages WHERE id = #{id.to_i}"
      else
        execute "UPDATE stages SET status = 'resolved', position = #{offset} WHERE id = #{id.to_i}"
        offset += 1
      end
    end
    execute "UPDATE stages SET status = 'done' WHERE status = 'resolved'"
  end

  def quote(value)
    connection.quote(value)
  end
end
