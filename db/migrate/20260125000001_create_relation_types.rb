# frozen_string_literal: true

class CreateRelationTypes < ActiveRecord::Migration[7.0]
  def change
    create_table :relation_types do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :relation_types, :name, unique: true
  end
end
