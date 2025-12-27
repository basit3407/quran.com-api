class CreateQiraatReadings < ActiveRecord::Migration[7.0]
  def up
    create_table :qiraat_readings do |t|
      t.references :qiraat_juncture, null: false, foreign_key: true
      t.string :text_uthmani, null: false
      t.string :text_imlaei
      t.string :grammatical_form
      t.string :root_letters
      t.integer :position, default: 0

      t.timestamps
    end

    # Note: qiraat_juncture_id index already created by t.references
    add_index :qiraat_readings, [:qiraat_juncture_id, :position],
              name: 'index_qiraat_readings_on_juncture_and_position'
  end

  def down
    drop_table :qiraat_readings
  end
end
