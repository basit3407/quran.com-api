class CreateLocalizedContents < ActiveRecord::Migration[7.0]
  def up
    create_table :localized_contents do |t|
      t.string :resource_type, null: false
      t.bigint :resource_id, null: false
      t.references :language, null: false, foreign_key: true
      t.string :content_type, null: false
      t.text :text
      t.text :short_text
      t.jsonb :metadata, default: {}
      t.string :source
      t.references :resource_content, foreign_key: true
      t.string :language_name
      t.integer :position, default: 0

      t.timestamps
    end

    # Polymorphic index for resource lookup
    add_index :localized_contents, [:resource_type, :resource_id],
              name: 'index_localized_contents_on_resource'

    # Language-filtered queries
    add_index :localized_contents, [:resource_type, :resource_id, :language_id],
              name: 'index_localized_contents_on_resource_and_language'

    # Specific content lookup
    add_index :localized_contents, [:resource_type, :resource_id, :language_id, :content_type],
              name: 'index_localized_contents_on_resource_lang_type'

    # Additional indexes for filtering
    add_index :localized_contents, :content_type

    # Unique constraint to prevent duplicates
    add_index :localized_contents,
              [:resource_type, :resource_id, :language_id, :content_type, :position],
              unique: true,
              name: 'index_localized_contents_unique'
  end

  def down
    drop_table :localized_contents
  end
end
