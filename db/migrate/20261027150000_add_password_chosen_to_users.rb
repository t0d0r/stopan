# Requesters created by the public form or the mailbox have a password they
# do not know until they choose one (specs/public-form.md).
class AddPasswordChosenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_chosen, :boolean, null: false, default: true
  end
end
