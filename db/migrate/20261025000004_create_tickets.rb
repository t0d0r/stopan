class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.integer :number, null: false
      t.string :subject, null: false
      t.text :description, null: false
      t.string :status, null: false, default: "new"
      t.string :priority, null: false, default: "normal"
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :organization, null: false, foreign_key: true
      t.datetime :resolved_at
      t.datetime :closed_at
      t.timestamps
    end
    add_index :tickets, :number, unique: true
    add_index :tickets, :status
    add_index :tickets, :updated_at

    create_table :comments do |t|
      t.references :ticket, null: false, foreign_key: true, index: false
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.boolean :internal, null: false, default: false
      t.timestamps
    end
    add_index :comments, %i[ticket_id created_at]

    create_table :ticket_events do |t|
      t.references :ticket, null: false, foreign_key: true, index: false
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :from_value
      t.string :to_value
      t.references :comment, foreign_key: true
      t.boolean :internal, null: false, default: false
      t.datetime :created_at, null: false
    end
    add_index :ticket_events, %i[ticket_id created_at]
  end
end
