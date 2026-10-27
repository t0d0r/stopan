# Board stages: admin-defined sub-columns of a status (specs/board.md
# "Stages").
class CreateStages < ActiveRecord::Migration[8.1]
  def change
    create_table :stages do |t|
      t.string :status, null: false
      t.string :name, null: false
      t.string :color, null: false, default: "gray"
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :stages, %i[status position]
    add_reference :tickets, :stage, foreign_key: { on_delete: :nullify }
  end
end
