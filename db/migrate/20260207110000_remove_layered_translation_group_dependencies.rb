# frozen_string_literal: true

class RemoveLayeredTranslationGroupDependencies < ActiveRecord::Migration[7.0]
  def up
    drop_table :layered_translation_group_dependencies, if_exists: true
  end

  def down
    return if table_exists?(:layered_translation_group_dependencies)

    create_table :layered_translation_group_dependencies do |t|
      t.references :layered_translation_group, null: false, foreign_key: true, index: { name: 'idx_lt_group_deps_on_group' }
      t.references :depends_on_verse,
                   null: false,
                   type: :integer,
                   foreign_key: { to_table: :verses },
                   index: { name: 'idx_lt_group_deps_on_verse' }
      t.string :depends_on_group_key, null: false

      t.timestamps
    end

    add_index :layered_translation_group_dependencies,
              [:layered_translation_group_id, :depends_on_verse_id, :depends_on_group_key],
              unique: true,
              name: 'idx_lt_group_deps_unique'
  end
end
