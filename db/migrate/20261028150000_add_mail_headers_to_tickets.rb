# The important headers of the mail a ticket came from
# (specs/organization-mail.md "Mail details").
class AddMailHeadersToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :mail_headers, :json
  end
end
