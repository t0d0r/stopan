# Administrators acting as another user (specs/admin.md "Impersonation").
class CreateImpersonations < ActiveRecord::Migration[8.1]
  def change
    create_table :impersonations do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }, index: false
      t.references :user, null: false, foreign_key: true, index: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :ip
    end
    add_index :impersonations, %i[user_id started_at]
    add_index :impersonations, :admin_id
  end
end
