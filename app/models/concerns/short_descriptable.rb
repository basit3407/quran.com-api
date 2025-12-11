# frozen_string_literal: true

module ShortDescriptable
  extend ActiveSupport::Concern

  included do
    has_many :short_descriptions, as: :resource
  end

  def short_description_for_language(language_code)
    language = Language.find_with_id_or_iso_code(language_code)
    return nil unless language
  
    default_id = Language.default.id
    short_descriptions.detect { |sd| sd.language_id == language.id } ||
      short_descriptions.detect { |sd| sd.language_id == default_id }
  end
end
