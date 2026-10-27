# The site-wide theme an administrator picks (specs/ui.md "Themes").
class AddDefaultLookToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :default_look, :string, null: false, default: "notes"
  end
end
