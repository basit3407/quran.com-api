# frozen_string_literal: true

# == Schema Information
#
# Table name: qiraat_reading_translations
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0)
#  source     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_qiraat_reading_translations_on_position  (position)
#  index_qiraat_reading_translations_on_source    (source)
#

class QiraatReadingTranslation < ApplicationRecord
  # Associations
  has_many :qiraat_reading_translation_memberships, dependent: :destroy
  has_many :qiraat_readings, through: :qiraat_reading_translation_memberships

  # Localized content for translation text
  has_many :localized_contents, as: :resource, dependent: :destroy

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :by_source, ->(source) { where(source: source) }
  scope :with_localized_content, -> { includes(:localized_contents) }

  # Get translation text for a specific language
  # Returns hash with id, text, and source for frontend grouping
  def translation_for(language)
    content = localized_contents.find_by(language: language, content_type: 'translation')
    return nil unless content

    {
      id: id,
      text: content.text,
      source: source || content.source
    }
  end

  # Get translation text for a specific language with English fallback
  # Returns hash with id, text, and source for frontend grouping
  def translation_for_with_fallback(language)
    # Try requested language first
    result = translation_for(language)
    return result if result.present?

    # Fallback to English if requested language is not English
    return nil if language.iso_code == 'en'

    english = Language.find_by(iso_code: 'en')
    return nil unless english

    translation_for(english)
  end

  # Convenience method to get just the text
  def translation_text_for(language)
    localized_contents.find_by(language: language, content_type: 'translation')&.text
  end

  # Convenience method to get just the text with English fallback
  def translation_text_for_with_fallback(language)
    # Try requested language first
    text = translation_text_for(language)
    return text if text.present?

    # Fallback to English
    return nil if language.iso_code == 'en'

    english = Language.find_by(iso_code: 'en')
    return nil unless english

    translation_text_for(english)
  end

  # Get all reading IDs that share this translation
  def shared_reading_ids
    qiraat_reading_translation_memberships.pluck(:qiraat_reading_id)
  end

  # Check if this translation is shared by multiple readings
  def shared?
    qiraat_reading_translation_memberships.count > 1
  end

  # Add a reading to this translation
  def add_reading(reading)
    qiraat_reading_translation_memberships.find_or_create_by!(qiraat_reading: reading)
  end

  # Remove a reading from this translation
  def remove_reading(reading)
    qiraat_reading_translation_memberships.find_by(qiraat_reading: reading)&.destroy
  end
end
