# Markdown per message (specs/markdown.md).
class AddMarkdownToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :markdown, :boolean, null: false, default: false
    add_column :comments, :markdown, :boolean, null: false, default: false
  end
end
