# The cleaned HTML part of the mail a ticket came from
# (specs/organization-mail.md "HTML view").
class AddMailHtmlToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :mail_html, :text
  end
end
