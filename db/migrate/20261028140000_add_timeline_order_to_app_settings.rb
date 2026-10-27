# The site's order of the ticket timeline (specs/timeline.md "Order of the
# timeline"); users may pick their own in a cookie.
class AddTimelineOrderToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :timeline_order, :string, null: false, default: "oldest_first"
  end
end
