class AddLocaleFieldsToCountryLanguagePreferences < ActiveRecord::Migration[7.0]
  def change
    add_column :country_language_preferences, :default_locale, :string
    add_column :country_language_preferences, :qr_default_locale, :string

    add_foreign_key :country_language_preferences,
                    :languages,
                    column: :default_locale,
                    primary_key: :iso_code,
                    on_delete: :cascade

    add_foreign_key :country_language_preferences,
                    :languages,
                    column: :qr_default_locale,
                    primary_key: :iso_code,
                    on_delete: :cascade
  end
end
