# frozen_string_literal: true
# == Schema Information
# Schema version: 20230313013539
#
# Table name: reciters
#
#  id                :integer          not null, primary key
#  bio               :text
#  cover_image       :string
#  name              :string
#  profile_picture   :string
#  recitations_count :integer          default(0)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class Reciter < ApplicationRecord
  include NameTranslateable
  include LocalizedContentFallback

  # Associations
  has_many :localized_contents, as: :resource, dependent: :destroy

  # Scopes
  scope :with_localized_content, -> { includes(:localized_contents) }

  # Get localized biography for a language with English fallback
  # @param language [Language] The requested language
  # @return [LocalizedContent, nil] The bio content or nil
  def bio_for(language)
    localized_content_for('bio', language)
  end

  # Get localized biography text with fallback to the static bio column
  # @param language [Language] The requested language
  # @return [String, nil] The localized bio text, or static bio if not found
  def localized_bio(language)
    localized_text_for('bio', language) || bio
  end
end
