# frozen_string_literal: true

# Migration to add shared reading explanations
# This allows multiple readings to share the same explanation without data duplication
class CreateQiraatReadingExplanations < ActiveRecord::Migration[7.0]
  def change
    # 1. Create the shareable explanation entity
    create_table :qiraat_reading_explanations do |t|
      t.string :source              # Attribution (e.g., "al-Alusi")
      t.integer :position, default: 0  # Display order if multiple

      t.timestamps
    end

    add_index :qiraat_reading_explanations, :source
    add_index :qiraat_reading_explanations, :position

    # 2. Create the N:M join table between readings and explanations
    create_table :qiraat_reading_explanation_memberships do |t|
      t.references :qiraat_reading, null: false, foreign_key: true, index: { name: 'idx_qr_expl_memb_reading' }
      t.references :qiraat_reading_explanation, null: false, foreign_key: true, index: { name: 'idx_qr_expl_memb_explanation' }

      t.timestamps
    end

    # Unique constraint to prevent duplicate memberships
    add_index :qiraat_reading_explanation_memberships,
              [:qiraat_reading_id, :qiraat_reading_explanation_id],
              unique: true,
              name: 'idx_qr_expl_membership_unique'
  end
end
