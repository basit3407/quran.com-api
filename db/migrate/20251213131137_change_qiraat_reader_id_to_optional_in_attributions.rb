# frozen_string_literal: true

class ChangeQiraatReaderIdToOptionalInAttributions < ActiveRecord::Migration[7.0]
  def up
    # Make qiraat_reader_id nullable since it can be derived from transmitter
    change_column_null :qiraat_reading_attributions, :qiraat_reader_id, true
  end

  def down
    # Before reverting, ensure all records have a reader_id (derive from transmitter if needed)
    execute <<-SQL
      UPDATE qiraat_reading_attributions
      SET qiraat_reader_id = (
        SELECT qiraat_transmitters.qiraat_reader_id
        FROM qiraat_transmitters
        WHERE qiraat_transmitters.id = qiraat_reading_attributions.qiraat_transmitter_id
      )
      WHERE qiraat_reader_id IS NULL AND qiraat_transmitter_id IS NOT NULL
    SQL

    change_column_null :qiraat_reading_attributions, :qiraat_reader_id, false
  end
end
