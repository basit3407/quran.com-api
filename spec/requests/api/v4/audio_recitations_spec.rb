# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::V4 Audio Recitations', type: :request do
  describe 'GET /api/v4/audio/reciters/:reciter_id/timestamp' do
    it 'returns the timestamp range from the presenter' do
      presenter = instance_double(Audio::SegmentPresenter, find_timestamp: { 'timestamp_from' => 10, 'timestamp_to' => 25 })

      allow(Audio::SegmentPresenter).to receive(:new).and_return(presenter)

      get '/api/v4/audio/reciters/7/timestamp', params: { chapter_number: 1 }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq('result' => { 'timestamp_from' => 10, 'timestamp_to' => 25 })
    end
  end

  describe 'GET /api/v4/audio/reciters/:reciter_id/lookup' do
    it 'returns the segment details from the presenter' do
      segment = instance_double(
        'AudioSegment',
        verse_key: '1:1',
        timestamp_from: 1000,
        timestamp_to: 5000,
        duration_ms: 4000,
        segments: [[0, 1000, 2500], [1, 2500, 5000]]
      )

      presenter = instance_double(
        Audio::SegmentPresenter,
        lookup_ayah: segment,
        include_segments?: true
      )

      allow(Audio::SegmentPresenter).to receive(:new).and_return(presenter)

      get '/api/v4/audio/reciters/7/lookup', params: { chapter_number: 1, timestamp: 2000, segments: true }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(
        'result' => {
          'verse_key' => '1:1',
          'timestamp_from' => 1000,
          'timestamp_to' => 5000,
          'duration' => 4000,
          'segments' => [[0, 1000, 2500], [1, 2500, 5000]]
        }
      )
    end

    it 'returns an empty result when no segment is found' do
      presenter = instance_double(
        Audio::SegmentPresenter,
        lookup_ayah: nil,
        include_segments?: false
      )

      allow(Audio::SegmentPresenter).to receive(:new).and_return(presenter)

      get '/api/v4/audio/reciters/7/lookup', params: { chapter_number: 1, timestamp: 2000 }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq('result' => {})
    end
  end
end
