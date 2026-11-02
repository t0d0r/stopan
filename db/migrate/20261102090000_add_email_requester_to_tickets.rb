# Whether the requester gets emails about the ticket (specs/notifications.md
# "Emails to the requester").
class AddEmailRequesterToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :email_requester, :boolean, default: true, null: false
  end
end
