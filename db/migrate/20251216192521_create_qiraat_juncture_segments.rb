# frozen_string_literal: true

class CreateQiraatJunctureSegments < ActiveRecord::Migration[7.0]
  def change
    create_table :qiraat_juncture_segments do |t|
      t.references :qiraat_juncture, null: false, foreign_key: true, index: true
      t.references :verse, null: false, foreign_key: true, index: true
      t.references :start_word, null: false, foreign_key: { to_table: :words }
      t.references :end_word, null: false, foreign_key: { to_table: :words }
      t.integer :position, default: 0, null: false
      t.string :verse_key

      t.timestamps
    end

    add_index :qiraat_juncture_segments, [:qiraat_juncture_id, :position], name: 'idx_juncture_segments_on_juncture_position'
  end
end
