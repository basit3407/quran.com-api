# frozen_string_literal: true

class CreateLayeredTranslationStructures < ActiveRecord::Migration[7.0]
  def change
    create_table :layered_translation_ayahs do |t|
      t.references :resource_content, null: false, type: :integer, foreign_key: true, index: true
      t.references :verse, null: false, type: :integer, foreign_key: true, index: true
      t.text :collapsed_template, null: false
      t.text :expanded_template, null: false

      t.timestamps
    end

    add_index :layered_translation_ayahs, [:resource_content_id, :verse_id], unique: true,
              name: 'idx_layered_translation_ayahs_on_resource_and_verse'

    create_table :layered_translation_groups do |t|
      t.references :layered_translation_ayah, null: false, foreign_key: true, index: true
      t.string :group_key, null: false
      t.integer :position, null: false, default: 1
      t.string :default_option_key, null: false
      t.text :explanation_html

      t.timestamps
    end

    add_index :layered_translation_groups, [:layered_translation_ayah_id, :group_key], unique: true,
              name: 'idx_layered_translation_groups_on_ayah_and_key'

    create_table :layered_translation_options do |t|
      t.references :layered_translation_group, null: false, foreign_key: true, index: { name: 'idx_lt_options_on_group' }
      t.string :option_key, null: false
      t.integer :position, null: false, default: 1
      t.text :collapsed_html, null: false
      t.text :expanded_html, null: false

      t.timestamps
    end

    add_index :layered_translation_options, [:layered_translation_group_id, :option_key], unique: true,
              name: 'idx_layered_translation_options_on_group_and_key'

    create_table :layered_translation_group_dependencies do |t|
      t.references :layered_translation_group, null: false, foreign_key: true, index: { name: 'idx_lt_group_deps_on_group' }
      t.references :depends_on_verse, null: false, type: :integer, foreign_key: { to_table: :verses }, index: { name: 'idx_lt_group_deps_on_verse' }
      t.string :depends_on_group_key, null: false

      t.timestamps
    end

    add_index :layered_translation_group_dependencies,
              [:layered_translation_group_id, :depends_on_verse_id, :depends_on_group_key],
              unique: true,
              name: 'idx_lt_group_deps_unique'

    add_reference :foot_notes, :layered_translation_ayah, foreign_key: true, index: true
  end
end
