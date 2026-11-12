# How often the current share link's page was opened, and when last
# (specs/sharing.md "Total views").
class AddShareViewsToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :share_views, :integer, default: 0, null: false
    add_column :tickets, :share_last_viewed_at, :datetime
  end
end
