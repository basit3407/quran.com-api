class AddTextSimpleToQiraatJunctures < ActiveRecord::Migration[7.0]
  def change
    add_column :qiraat_junctures, :text_simple, :string
  end
end
