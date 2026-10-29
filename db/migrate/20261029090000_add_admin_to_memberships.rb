# The organization admin mark (specs/org-admins.md).
class AddAdminToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :admin, :boolean, default: false, null: false
  end
end
