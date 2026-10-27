# The DeepL key is entered on /admin/settings and stored encrypted
# (specs/translation.md "Switching it on").
class AddDeeplApiKeyToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :deepl_api_key, :text
  end
end
