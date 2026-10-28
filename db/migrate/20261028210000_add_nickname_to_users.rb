# A short name for the menu bar (specs/data-model.md "users").
class AddNicknameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nickname, :string
  end
end
