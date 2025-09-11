# frozen_string_literal: true

module NameTransliterateable
  extend ActiveSupport::Concern

  included do
    has_many :transliterations, as: :resource
    has_one :transliteration, as: :resource
  end

  def localised_transliteration
    transliteration&.text
  end
end
