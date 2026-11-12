# The cleaned HTML part of a reply that came in by mail, as tickets have
# (specs/organization-mail.md "HTML view").
class AddMailHtmlToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :mail_html, :text
  end
end
