class AddQrFieldsToCountryLanguagePreferences < ActiveRecord::Migration[7.0]
  def change
    add_column :country_language_preferences, :qr_default_translations_ids, :string
    add_column :country_language_preferences, :qr_reflection_languages, :string
  end
end
