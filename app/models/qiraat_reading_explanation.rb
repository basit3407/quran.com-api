# frozen_string_literal: true

# == Schema Information
#
# Table name: qiraat_reading_explanations
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0)
#  source     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_qiraat_reading_explanations_on_position  (position)
#  index_qiraat_reading_explanations_on_source    (source)
#

class QiraatReadingExplanation < ApplicationRecord
  # Associations
  has_many :qiraat_reading_explanation_memberships, dependent: :destroy
  has_many :qiraat_readings, through: :qiraat_reading_explanation_memberships

  # Localized content for explanation text
  has_many :localized_contents, as: :resource, dependent: :destroy

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :by_source, ->(source) { where(source: source) }
  scope :with_localized_content, -> { includes(:localized_contents) }

  # Get explanation text for a specific language
  # Returns hash with id, text, and source for frontend grouping
  def explanation_for(language)
    content = localized_contents.find_by(language: language, content_type: 'explanation')
    return nil unless content

    {
      id: id,
      text: content.text,
      source: source || content.source
    }
  end

  # Get explanation text for a specific language with English fallback
  # Returns hash with id, text, and source for frontend grouping
  # Does NOT fallback for Arabic requests
  def explanation_for_with_fallback(language)
    # Try requested language first
    result = explanation_for(language)
    return result if result && result[:text].present?

    # Fallback to English if requested language is not English or Arabic
    return nil if language.iso_code.in?(['en', 'ar'])

    english = Language.find_by(iso_code: 'en')
    return nil unless english

    explanation_for(english)
  end

  # Convenience method to get just the text
  def explanation_text_for(language)
    localized_contents.find_by(language: language, content_type: 'explanation')&.text
  end

  # Convenience method to get just the text with English fallback
  # Does NOT fallback for Arabic requests
  def explanation_text_for_with_fallback(language)
    # Try requested language first
    text = explanation_text_for(language)
    return text if text.present?

    # Fallback to English (but NOT for Arabic)
    return nil if language.iso_code.in?(['en', 'ar'])

    english = Language.find_by(iso_code: 'en')
    return nil unless english

    explanation_text_for(english)
  end

  # Get all reading IDs that share this explanation
  def shared_reading_ids
    qiraat_reading_explanation_memberships.pluck(:qiraat_reading_id)
  end

  # Check if this explanation is shared by multiple readings
  def shared?
    qiraat_reading_explanation_memberships.count > 1
  end

  # Add a reading to this explanation
  def add_reading(reading)
    qiraat_reading_explanation_memberships.find_or_create_by!(qiraat_reading: reading)
  end

  # Remove a reading from this explanation
  def remove_reading(reading)
    qiraat_reading_explanation_memberships.find_by(qiraat_reading: reading)&.destroy
  end
end
