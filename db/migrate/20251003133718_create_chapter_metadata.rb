# frozen_string_literal: true

class CreateChapterMetadata < ActiveRecord::Migration[7.0]
  def change
    create_table :chapter_metadata do |t|
      t.integer :chapter_id, null: false
      t.string :metadata_type, null: false
      t.text :content, null: false
      t.integer :language_id, null: false
      t.integer :resource_content_id
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :chapter_metadata, [:chapter_id, :language_id, :metadata_type, :is_active], name: 'index_chapter_metadata_on_query_pattern'

    add_foreign_key :chapter_metadata, :chapters, column: :chapter_id
    add_foreign_key :chapter_metadata, :languages, column: :language_id

    add_check_constraint :chapter_metadata, "metadata_type IN ('summary', 'suggestion')", name: 'check_metadata_type'
  end
end
