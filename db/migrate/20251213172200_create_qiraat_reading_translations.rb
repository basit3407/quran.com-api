# frozen_string_literal: true

class CreateQiraatReadingTranslations < ActiveRecord::Migration[7.0]
  def change
    # 1. Reading Translations (shareable across readings)
    # Mirrors the qiraat_reading_explanations pattern
    create_table :qiraat_reading_translations do |t|
      t.string :source           # Attribution (e.g., "Bridges Translation")
      t.integer :position, default: 0
      t.timestamps
    end
    add_index :qiraat_reading_translations, :source
    add_index :qiraat_reading_translations, :position

    # 2. Reading Translation Memberships (N:M join)
    create_table :qiraat_reading_translation_memberships do |t|
      t.references :qiraat_reading, null: false, foreign_key: true, index: { name: 'idx_qr_trans_memb_on_reading' }
      t.references :qiraat_reading_translation, null: false, foreign_key: true, index: { name: 'idx_qr_trans_memb_on_trans' }
      t.timestamps
    end
    add_index :qiraat_reading_translation_memberships,
              [:qiraat_reading_id, :qiraat_reading_translation_id],
              unique: true, name: 'idx_qr_trans_membership_unique'
  end
end
