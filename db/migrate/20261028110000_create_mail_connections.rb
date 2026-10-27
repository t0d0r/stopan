# Google accounts for organization mail (specs/mail-oauth.md): the OAuth
# client on app_settings, one connection per organization, and how the
# organization's mail signs in.
class CreateMailConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_connections do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false
      t.string :email, null: false
      t.text :refresh_token, null: false
      t.string :status, null: false, default: "connected"
      t.datetime :connected_at, null: false
      t.text :last_error
      t.timestamps
    end
    add_column :organizations, :mail_auth, :string, null: false, default: "password"
    add_column :app_settings, :google_client_id, :string
    add_column :app_settings, :google_client_secret, :text
  end
end
