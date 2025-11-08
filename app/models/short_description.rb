# frozen_string_literal: true

class ShortDescription < ApplicationRecord
  belongs_to :resource, polymorphic: true
end


