# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health endpoint', type: :request do
  describe 'GET /health' do
    it 'returns simple ok with no caching headers' do
      get '/health'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq({ 'status' => 'ok' })
      expect(response.headers['Cache-Control']).to match(/no-store/)
      expect(response.headers['Pragma']).to eq('no-cache')
      expect(response.headers['Expires']).to eq('0')
    end
  end
end
