# frozen_string_literal: true

class CreateChapterMetadata < ActiveRecord::Migration[7.0]
  def change
    create_table :chapter_metadata do |t|
      t.integer :chapter_id, null: false
      t.string :metadata_type, null: false
      t.text :content, null: false
      t.integer :language_id, null: false
      t.string :language_name
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :chapter_metadata, :chapter_id
    add_index :chapter_metadata, [:chapter_id, :metadata_type]
    add_index :chapter_metadata, [:chapter_id, :is_active]
    add_index :chapter_metadata, :language_id
    add_index :chapter_metadata, [:chapter_id, :metadata_type, :is_active], name: 'index_chapter_metadata_on_chapter_type_active'
    add_index :chapter_metadata, [:language_id, :is_active], name: 'index_chapter_metadata_on_language_active'

    add_foreign_key :chapter_metadata, :chapters, column: :chapter_id
    add_foreign_key :chapter_metadata, :languages, column: :language_id
  end
end
