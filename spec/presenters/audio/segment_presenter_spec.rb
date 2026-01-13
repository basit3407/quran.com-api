# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audio::SegmentPresenter do
  describe '#lookup_ayah' do
    it 'returns nil when there are no segments' do
      presenter = described_class.new(
        chapter_number: 1,
        reciter_id: 7,
        timestamp: 2000
      )

      allow(presenter).to receive(:audio_file_segments).and_return([])

      expect(presenter.lookup_ayah).to be_nil
    end
  end
end
