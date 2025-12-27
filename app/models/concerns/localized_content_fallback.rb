# frozen_string_literal: true

# Model concern for localized content with language fallback
# Provides helper methods for fetching localized content from the
# localized_contents association with automatic English fallback.
#
# Usage:
#   class QiraatReader < ApplicationRecord
#     include LocalizedContentFallback
#     has_many :localized_contents, as: :resource
#   end
#
#   reader.localized_content_for('name', language)  # Returns LocalizedContent or nil
#   reader.localized_text_for('name', language)     # Returns String or nil
#
module LocalizedContentFallback
  extend ActiveSupport::Concern

  # Get localized content with fallback to English
  # Uses already-loaded localized_contents association to avoid N+1 queries
  # @param content_type [String] The type of content ('name', 'bio', 'translation', etc.)
  # @param language [Language] The requested language (can be nil)
  # @return [LocalizedContent, nil] The content in requested language or English, or nil
  def localized_content_for(content_type, language)
    # Return nil if language is not provided
    return nil unless language

    lc = localized_contents.find { |c| c.language_id == language.id && c.content_type == content_type }
    return lc if lc&.text.present?

    # Fallback to English if requested language is not English
    return nil if language.iso_code == 'en'

    english = Language.find_by(iso_code: 'en')
    return nil unless english

    localized_contents.find { |c| c.language_id == english.id && c.content_type == content_type }
  end

  # Get text from localized content with fallback to English
  # @param content_type [String] The type of content
  # @param language [Language] The requested language
  # @return [String, nil] The text in requested language or English, or nil
  def localized_text_for(content_type, language)
    localized_content_for(content_type, language)&.text
  end
end
