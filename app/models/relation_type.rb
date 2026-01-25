# frozen_string_literal: true

# == Schema Information
# Schema version: 20260101000001
#
# Table name: relation_types
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_relation_types_on_name  (name) UNIQUE
#

class RelationType < ApplicationRecord
  include LocalizedContentFallback

  has_many :localized_contents, as: :resource, dependent: :destroy
  has_many :related_verses, dependent: :restrict_with_error

  # For eager loading a single translation
  has_one :localized_content, -> { where(content_type: 'translation') }, as: :resource

  validates :name, presence: true, uniqueness: true

  # Get localized name with English fallback
  # @param language [Language] The requested language
  # @return [String] The localized name or the default name
  def localized_name_for(language)
    localized_text_for('translation', language) || name&.titleize
  end
end