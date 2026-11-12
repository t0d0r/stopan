# Days after which a pending ticket without activity is marked done; 0 is
# off (specs/board.md "Automatic done").
class AddAutoDoneDaysToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :auto_done_days, :integer, default: 0, null: false
  end
end
