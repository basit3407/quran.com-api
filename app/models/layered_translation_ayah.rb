# frozen_string_literal: true

require 'set'

# == Schema Information
# Schema version: 20260206100000
#
# Table name: layered_translation_ayahs
#
#  id                  :bigint           not null, primary key
#  collapsed_template  :text             not null
#  expanded_template   :text             not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer          not null
#  verse_id            :integer          not null
#
# Indexes
#
#  idx_layered_translation_ayahs_on_resource_and_verse     (resource_content_id,verse_id) UNIQUE
#  index_layered_translation_ayahs_on_resource_content_id  (resource_content_id)
#  index_layered_translation_ayahs_on_verse_id             (verse_id)
#
# Foreign Keys
#
#  fk_rails_1c13fbb352  (resource_content_id => resource_contents.id)
#  fk_rails_8c4faf31a3  (verse_id => verses.id)
#
class LayeredTranslationAyah < ApplicationRecord
  TOKEN_PATTERN = /\{\{\s*g:([A-Za-z0-9_-]+)\s*\}\}/.freeze

  belongs_to :resource_content
  belongs_to :verse

  has_many :layered_translation_groups, -> { order(:position, :id) }, dependent: :destroy
  has_many :foot_notes, dependent: :nullify

  validates :collapsed_template, presence: true
  validates :expanded_template, presence: true
  validates :resource_content_id, uniqueness: { scope: :verse_id }
  validate :templates_only_reference_existing_group_keys

  def collapsed_tokens
    tokenize_template(collapsed_template)
  end

  def expanded_tokens
    tokenize_template(expanded_template)
  end

  def tokenize_template(template)
    value = template.to_s
    return [] if value.blank?

    tokens = []
    cursor = 0

    while (match = TOKEN_PATTERN.match(value, cursor))
      prefix = value[cursor...match.begin(0)]
      tokens << { type: 'text', html: prefix } if prefix.present?

      tokens << { type: 'alt_group', group_key: match[1] }
      cursor = match.end(0)
    end

    suffix = value[cursor..]
    tokens << { type: 'text', html: suffix } if suffix.present?

    tokens
  end

  private

  def templates_only_reference_existing_group_keys
    return unless layered_translation_groups.loaded? || layered_translation_groups.exists?

    available_group_keys = layered_translation_groups.map(&:group_key).to_set
    referenced_group_keys = extract_group_keys_from_templates
    missing = referenced_group_keys - available_group_keys
    return if missing.empty?

    errors.add(:base, "Missing groups referenced in templates: #{missing.to_a.sort.join(', ')}")
  end

  def extract_group_keys_from_templates
    [collapsed_template.to_s, expanded_template.to_s].flat_map do |template|
      template.scan(TOKEN_PATTERN).flatten
    end.to_set
  end
end
