# frozen_string_literal: true

class RemoveColorCodeFromQiraatReaders < ActiveRecord::Migration[7.0]
  def change
    remove_column :qiraat_readers, :color_code, :string
  end
end
