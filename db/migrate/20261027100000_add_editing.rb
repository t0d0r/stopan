# Editing the request and replies (specs/timeline.md "Editing"): who last
# edited, and the earlier versions.
class AddEditing < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :edited_at, :datetime
    add_reference :tickets, :edited_by, foreign_key: { to_table: :users }
    add_column :comments, :edited_at, :datetime
    add_reference :comments, :edited_by, foreign_key: { to_table: :users }

    create_table :revisions do |t|
      t.references :record, polymorphic: true, null: false, index: false
      t.references :editor, null: false, foreign_key: { to_table: :users }
      t.string :subject
      t.text :body, null: false
      t.datetime :created_at, null: false
    end
    add_index :revisions, %i[record_type record_id created_at]
  end
end
