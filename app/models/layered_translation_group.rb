# frozen_string_literal: true

# == Schema Information
# Schema version: 20260206100000
#
# Table name: layered_translation_groups
#
#  id                          :bigint           not null, primary key
#  default_option_key          :string           not null
#  explanation_html            :text
#  group_key                   :string           not null
#  position                    :integer          default(1), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  layered_translation_ayah_id :bigint           not null
#
# Indexes
#
#  idx_layered_translation_groups_on_ayah_and_key                   (layered_translation_ayah_id,group_key) UNIQUE
#  index_layered_translation_groups_on_layered_translation_ayah_id  (layered_translation_ayah_id)
#
# Foreign Keys
#
#  fk_rails_652fc87270  (layered_translation_ayah_id => layered_translation_ayahs.id)
#
class LayeredTranslationGroup < ApplicationRecord
  belongs_to :layered_translation_ayah

  has_many :layered_translation_options, -> { order(:position, :id) }, dependent: :destroy

  validates :group_key, presence: true
  validates :default_option_key, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :group_key, uniqueness: { scope: :layered_translation_ayah_id }
  validate :default_option_key_exists

  private

  def default_option_key_exists
    options_loaded = layered_translation_options.loaded?
    has_any_options = options_loaded ? layered_translation_options.any? : layered_translation_options.exists?
    return unless has_any_options

    option_exists = if options_loaded
                      layered_translation_options.any? { |option| option.option_key == default_option_key }
                    else
                      layered_translation_options.where(option_key: default_option_key).exists?
                    end
    return if option_exists

    errors.add(:default_option_key, 'must match an option key on this group')
  end
end
