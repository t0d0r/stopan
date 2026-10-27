# Who may use an organization's public request page (specs/public-form.md
# "Allowed senders").
class AddPublicAllowedSendersToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :public_allowed_senders, :text
  end
end
