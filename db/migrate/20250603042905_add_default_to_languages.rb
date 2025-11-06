class AddDefaultToLanguages < ActiveRecord::Migration[7.0]
  def change
    add_column :languages, :default, :boolean
  end
end
