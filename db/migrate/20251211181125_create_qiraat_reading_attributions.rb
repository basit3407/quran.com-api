class CreateQiraatReadingAttributions < ActiveRecord::Migration[7.0]
  def up
    create_table :qiraat_reading_attributions do |t|
      t.references :qiraat_reading, null: false, foreign_key: true
      t.references :qiraat_reader, null: false, foreign_key: true
      t.references :qiraat_transmitter, foreign_key: true

      t.timestamps
    end

    # Note: Individual foreign key indexes already created by t.references
    # Only add the composite unique index
    add_index :qiraat_reading_attributions,
              [:qiraat_reading_id, :qiraat_reader_id, :qiraat_transmitter_id],
              unique: true,
              name: 'index_qiraat_attributions_unique'
  end

  def down
    drop_table :qiraat_reading_attributions
  end
end
