# The headers of a reply that came in by mail (specs/organization-mail.md
# "Mail details").
class AddMailHeadersToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :mail_headers, :json
  end
end
