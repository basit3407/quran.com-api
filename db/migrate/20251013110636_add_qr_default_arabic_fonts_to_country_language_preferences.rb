class AddQrDefaultArabicFontsToCountryLanguagePreferences < ActiveRecord::Migration[7.0]
  def change
    add_column :country_language_preferences, :qr_default_arabic_fonts, :string
  end
end
