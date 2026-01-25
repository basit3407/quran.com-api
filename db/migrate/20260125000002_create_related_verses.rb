# frozen_string_literal: true

class CreateRelatedVerses < ActiveRecord::Migration[7.0]
  def up
    create_table :related_verses do |t|
      t.references :verse, null: false, foreign_key: true
      t.bigint :related_verse_id, null: false
      t.references :relation_type, null: false, foreign_key: true
      t.boolean :approved, default: false, null: false

      t.timestamps
    end

    # Foreign key for related_verse_id pointing to verses table
    add_foreign_key :related_verses, :verses, column: :related_verse_id

    # Indexes for efficient queries
    add_index :related_verses, :related_verse_id
    add_index :related_verses, [:verse_id, :approved]
    add_index :related_verses, [:related_verse_id, :approved]

    # Unique constraint to prevent duplicate relationships
    add_index :related_verses,
              [:verse_id, :related_verse_id, :relation_type_id],
              unique: true,
              name: 'index_related_verses_unique'

    # Bidirectional unique constraint to prevent both A->B and B->A
    execute <<-SQL
      CREATE UNIQUE INDEX index_related_verses_bidirectional_unique 
      ON related_verses (
        LEAST(verse_id, related_verse_id),
        GREATEST(verse_id, related_verse_id),
        relation_type_id
      );
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS index_related_verses_bidirectional_unique;
    SQL
    drop_table :related_verses
  end
end