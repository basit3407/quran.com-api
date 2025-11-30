# frozen_string_literal: true

module ShortDescriptable
  extend ActiveSupport::Concern

  included do
    has_many :short_descriptions, as: :resource

    # For eager loading
    has_one :short_description, as: :resource
  end
end
