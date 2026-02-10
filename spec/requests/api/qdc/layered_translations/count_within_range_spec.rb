# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::LayeredTranslations count_within_range', type: :request do
  before do
    create(:language, :english) unless Language.exists?(iso_code: 'en')
  end

  def parsed
    JSON.parse(response.body)
  end

  it 'returns 400 when from/to are missing' do
    get '/api/qdc/layered_translations/count_within_range'

    expect(response).to have_http_status(:bad_request)
    expect(parsed['error']['code']).to eq('INVALID_PARAMETER')
    expect(parsed['error']['message']).to be_present
  end

  it 'returns 400 for invalid verse key format' do
    get '/api/qdc/layered_translations/count_within_range', params: { from: 'invalid', to: '1:1' }

    expect(response).to have_http_status(:bad_request)
    expect(parsed['error']['code']).to eq('INVALID_PARAMETER')
    expect(parsed['error']['message']).to include('Invalid verse_key format')
  end

  it 'returns 400 for out-of-range verse keys (e.g., 1:8)' do
    get '/api/qdc/layered_translations/count_within_range', params: { from: '1:1', to: '1:8' }

    expect(response).to have_http_status(:bad_request)
    expect(parsed['error']['code']).to eq('INVALID_PARAMETER')
    expect(parsed['error']['message']).to include('Invalid verse keys')
    expect(parsed.dig('error', 'details', 'to')).to eq('1:8')
  end

  it 'never 500s when verse_counts is nil in the view' do
    # This is a regression test for the streamer template calling `each` on nil.
    allow_any_instance_of(Api::Qdc::LayeredTranslationsController).to receive(:resolve_resource).and_return([nil, false])

    get '/api/qdc/layered_translations/count_within_range', params: { from: '1:1', to: '1:1' }

    expect(response).to have_http_status(:success)
    expect(parsed).to eq({})
  end
end
