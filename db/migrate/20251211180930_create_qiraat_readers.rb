class CreateQiraatReaders < ActiveRecord::Migration[7.0]
  def up
    create_table :qiraat_readers do |t|
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.integer :death_year_hijri
      t.integer :death_year_gregorian
      t.integer :position
      t.string :color_code
      t.jsonb :name_translations, default: {}

      t.timestamps
    end

    add_index :qiraat_readers, :abbreviation, unique: true
    add_index :qiraat_readers, :position
  end

  def down
    drop_table :qiraat_readers
  end
end
