# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShortDescription, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:resource) }
    it { is_expected.to belong_to(:language) }
  end
end
