# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::LayeredTranslations by_verse', type: :request do
  def parsed
    JSON.parse(response.body)
  end

  it 'returns 400 for invalid verse key format' do
    get '/api/qdc/layered_translations/by_verse/invalid'

    expect(response).to have_http_status(:bad_request)
    expect(parsed['error']['code']).to eq('INVALID_PARAMETER')
    expect(parsed['error']['message']).to include('Invalid verse_key format')
  end

  it 'returns 404 when verse is not found' do
    allow(Verse).to receive(:find_by).with(verse_key: '67:1').and_return(nil)

    get '/api/qdc/layered_translations/by_verse/67:1'

    expect(response).to have_http_status(:not_found)
    expect(parsed['error']['code']).to eq('NOT_FOUND')
    expect(parsed['error']['message']).to include('Verse 67:1 not found')
  end

  it 'returns 404 when no layered translation resource can be resolved' do
    allow(Verse).to receive(:find_by).with(verse_key: '67:1').and_return(double('Verse', id: 1))
    allow_any_instance_of(Api::Qdc::LayeredTranslationsController).to receive(:resolve_resource).and_return([nil, false])

    get '/api/qdc/layered_translations/by_verse/67:1'

    expect(response).to have_http_status(:not_found)
    expect(parsed['error']['code']).to eq('NOT_FOUND')
    expect(parsed['error']['message']).to include('No layered translation resource found')
  end
end

