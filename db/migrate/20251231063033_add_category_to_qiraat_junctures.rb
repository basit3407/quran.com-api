class AddCategoryToQiraatJunctures < ActiveRecord::Migration[7.0]
  def change
    add_column :qiraat_junctures, :category, :string
    add_index :qiraat_junctures, :category
  end
end
