class CreateShortDescriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :short_descriptions do |t|
      t.integer :resource_id, null: false
      t.string :resource_type, null: false
      t.references :language, null: false, foreign_key: true
      t.string :description, limit: 50
      t.string :language_name
      t.integer :language_priority

      t.timestamps
    end

    add_index :short_descriptions, :language_priority
    add_index :short_descriptions, [:resource_type, :resource_id]
  end
end