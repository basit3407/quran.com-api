class AddApprovedToQiraatJunctures < ActiveRecord::Migration[7.0]
  def change
    add_column :qiraat_junctures, :approved, :boolean, default: false, null: false
    add_index :qiraat_junctures, :approved
  end
end
