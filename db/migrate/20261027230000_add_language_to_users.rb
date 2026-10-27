# The language a user chose in the header or on the account page
# (specs/ui.md "Language"); nil follows the browser.
class AddLanguageToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :language, :string
  end
end
