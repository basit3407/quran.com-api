# frozen_string_literal: true

class CreateHadithReferences < ActiveRecord::Migration[7.0]
  def change
    create_table :hadith_references do |t|
      t.string :collection, null: false
      t.string :hadith_number, null: false
      t.integer :our_hadith_number, null: false
      t.bigint :arabic_urn, null: false
      t.bigint :english_urn, null: false
      t.integer :ayah_start_index, null: false
      t.integer :ayah_end_index, null: false

      t.timestamps
    end

    add_index :hadith_references,
              :ayah_start_index,
              name: 'index_hadith_refs_on_ayah_start_index'

    add_index :hadith_references,
              :ayah_end_index,
              name: 'index_hadith_refs_on_ayah_end_index'

    add_index :hadith_references,
              [:collection, :hadith_number],
              name: 'index_hadith_refs_on_collection_and_hadith_number'
  end
end
