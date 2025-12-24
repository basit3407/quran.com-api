# frozen_string_literal: true

module Api
  module Qdc
    module Qiraat
      module Concerns
        # Helper module for language fallback logic in controllers
        # Always tries requested language first, then falls back to English
        #
        # For models, use LocalizedContentFallback concern in app/models/concerns/
        module LanguageFallback
          extend ActiveSupport::Concern

          private

          # Get localized content with fallback to English
          # @param record [ActiveRecord::Base] The record to get content from
          # @param content_type [String] The type of content ('translation', 'explanation', etc.)
          # @param language [Language] The requested language
          # @return [LocalizedContent, nil] The content in requested language or English, or nil
          def find_localized_content_with_fallback(record, content_type:, language:)
            # Try requested language first
            content = record.localized_contents.find_by(language: language, content_type: content_type)
            return content if content.present?

            # Fallback to English if requested language is not English
            return nil if language.iso_code == 'en'

            english = Language.find_by(iso_code: 'en')
            return nil unless english

            record.localized_contents.find_by(language: english, content_type: content_type)
          end

          # Get text from localized content with fallback to English
          # @param record [ActiveRecord::Base] The record to get content from
          # @param content_type [String] The type of content
          # @param language [Language] The requested language
          # @return [String, nil] The text in requested language or English, or nil
          def get_localized_text_with_fallback(record, content_type:, language:)
            find_localized_content_with_fallback(record, content_type: content_type, language: language)&.text
          end
        end
      end
    end
  end
end
