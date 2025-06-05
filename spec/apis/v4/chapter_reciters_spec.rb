require 'spec_helper'

describe 'Chapter reciters endpoint', type: :api do
  context 'when no recitations exist' do
    it 'returns an empty list' do
      get '/api/v4/resources/chapter_reciters', chapter_id: 1
      expect(last_response.status).to eq(200)
      expect(Oj.load(last_response.body)['reciters']).to eq([])
    end
  end
end
