# Personal tokens for the JSON API (specs/api.md "Tokens"); only a digest
# of each token is kept.
class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :token_digest, null: false, index: { unique: true }
      t.string :token_hint, null: false
      t.boolean :read_only, null: false, default: false
      t.datetime :expires_at
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
