# Settings of the whole service desk, one row (specs/board.md "Automatic
# postponing").
class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.integer :auto_postpone_days, null: false, default: 30
      t.timestamps
    end
  end
end
