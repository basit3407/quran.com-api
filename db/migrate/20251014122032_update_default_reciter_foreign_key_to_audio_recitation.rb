class UpdateDefaultReciterForeignKeyToAudioRecitation < ActiveRecord::Migration[7.0]
  def change
    # Remove the existing foreign key constraint to reciters table
    remove_foreign_key :country_language_preferences, :reciters, column: :default_reciter

    # Add the new foreign key constraint to audio_recitations table
    add_foreign_key :country_language_preferences, :audio_recitations, column: :default_reciter, on_delete: :cascade
  end
end
