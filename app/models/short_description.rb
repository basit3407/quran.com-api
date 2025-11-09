# frozen_string_literal: true

class ShortDescription < ApplicationRecord
  include LanguageFilterable

  belongs_to :resource, polymorphic: true
end
