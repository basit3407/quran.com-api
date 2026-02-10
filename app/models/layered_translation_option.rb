# frozen_string_literal: true

# == Schema Information
# Schema version: 20260206100000
#
# Table name: layered_translation_options
#
#  id                           :bigint           not null, primary key
#  collapsed_html               :text             not null
#  expanded_html                :text             not null
#  option_key                   :string           not null
#  position                     :integer          default(1), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  layered_translation_group_id :bigint           not null
#
# Indexes
#
#  idx_layered_translation_options_on_group_and_key  (layered_translation_group_id,option_key) UNIQUE
#  idx_lt_options_on_group                           (layered_translation_group_id)
#
# Foreign Keys
#
#  fk_rails_d31373f224  (layered_translation_group_id => layered_translation_groups.id)
#
class LayeredTranslationOption < ApplicationRecord
  belongs_to :layered_translation_group

  validates :option_key, presence: true
  validates :collapsed_html, presence: true
  validates :expanded_html, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :option_key, uniqueness: { scope: :layered_translation_group_id }
end

