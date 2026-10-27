# Machine translations of messages for staff (specs/translation.md), and
# the administrator's switch for them.
class CreateTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :translations do |t|
      t.string :translatable_type, null: false
      t.integer :translatable_id, null: false
      t.string :target_language, null: false
      t.string :source_language, null: false
      t.text :text, null: false
      t.string :source_digest, null: false
      t.timestamps
    end
    add_index :translations, %i[translatable_type translatable_id target_language], unique: true,
                                                                                    name: "index_translations_on_message_and_language"
    add_column :app_settings, :translation_enabled, :boolean, null: false, default: false
  end
end
