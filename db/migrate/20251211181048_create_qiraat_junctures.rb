# frozen_string_literal: true

class CreateQiraatJunctures < ActiveRecord::Migration[7.0]
  def change
    create_table :qiraat_junctures do |t|
      # Word references are handled by qiraat_juncture_segments table
      t.integer :juz_number
      t.integer :hizb_number
      t.integer :position, default: 0
      t.string :flags, array: true, default: []

      t.timestamps
    end

    add_index :qiraat_junctures, :juz_number
    add_index :qiraat_junctures, :hizb_number
  end
end
