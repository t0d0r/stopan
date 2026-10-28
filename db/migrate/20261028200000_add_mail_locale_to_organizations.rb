# The language of an organization's emails to its requesters
# (specs/organization-mail.md "Settings"); nil follows each recipient.
class AddMailLocaleToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :mail_locale, :string
  end
end
