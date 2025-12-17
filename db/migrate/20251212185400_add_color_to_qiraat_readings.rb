# frozen_string_literal: true

class AddColorToQiraatReadings < ActiveRecord::Migration[7.0]
  def change
    # Add color field to qiraat_readings
    # Color is stored per reading (not per reader) because:
    # - Colors are assigned based on the reading's position in the juncture
    # - White (#f5f5f5) is typically for ʿĀṣim/normative reading
    # - Other colors (green, blue, pink) are assigned based on commonality
    add_column :qiraat_readings, :color, :string, default: '#f5f5f5'
  end
end
