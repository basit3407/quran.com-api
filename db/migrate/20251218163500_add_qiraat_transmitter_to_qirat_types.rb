# frozen_string_literal: true

class AddQiraatTransmitterToQiratTypes < ActiveRecord::Migration[7.0]
  def change
    add_reference :qirat_types, :qiraat_transmitter, foreign_key: true, index: true
  end
end
