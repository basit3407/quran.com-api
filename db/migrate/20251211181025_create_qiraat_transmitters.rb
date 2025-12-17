class CreateQiraatTransmitters < ActiveRecord::Migration[7.0]
  def up
    create_table :qiraat_transmitters do |t|
      t.references :qiraat_reader, null: false, foreign_key: true
      t.string :name, null: false
      t.string :abbreviation
      t.integer :death_year_hijri
      t.integer :death_year_gregorian
      t.integer :position
      t.boolean :is_primary, default: false
      t.jsonb :name_translations, default: {}

      t.timestamps
    end

    # Note: qiraat_reader_id index already created by t.references
    add_index :qiraat_transmitters, [:qiraat_reader_id, :position],
              name: 'index_qiraat_transmitters_on_reader_and_position'
    add_index :qiraat_transmitters, :abbreviation
  end

  def down
    drop_table :qiraat_transmitters
  end
end
