# Public request page per organization and where tickets and comments came
# from (specs/public-form.md, specs/organization-mail.md).
class AddPublicFormAndSources < ActiveRecord::Migration[8.1]
  def up
    change_table :organizations, bulk: true do |t|
      t.string :slug
      t.boolean :public_form, null: false, default: false
      t.text :public_intro
    end
    add_column :tickets, :source, :string, null: false, default: "app"
    add_column :comments, :source, :string, null: false, default: "app"

    # Existing organizations get a URL name from their name, made unique.
    taken = []
    select_rows("SELECT id, name FROM organizations ORDER BY id").each do |id, name|
      base = name.to_s.parameterize.first(50).delete_suffix("-").presence || "organization"
      slug = base
      slug = "#{base}-#{taken.count { |s| s.start_with?(base) } + 1}" while taken.include?(slug)
      taken << slug
      execute("UPDATE organizations SET slug = #{quote(slug)} WHERE id = #{Integer(id)}")
    end
    add_index :organizations, :slug, unique: true
  end

  def down
    remove_index :organizations, :slug
    remove_columns :organizations, :slug, :public_form, :public_intro
    remove_column :tickets, :source
    remove_column :comments, :source
  end
end
