# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Readiness endpoint', type: :request do
  describe 'GET /ready' do
    it 'returns checks and ok when all up (or degraded if something down)' do
      get '/ready'
      expect([200, 503]).to include(response.status)
      json = JSON.parse(response.body)
      expect(json).to include('status', 'checks')
      expect(json['checks']).to be_a(Hash)
      %w[database redis elasticsearch].each do |k|
        expect(json['checks']).to have_key(k)
      end
      expect(%w[ok degraded]).to include(json['status'])
      if response.status == 200
        expect(json['status']).to eq('ok')
      else
        expect(json['status']).to eq('degraded')
      end
      expect(response.headers['Cache-Control']).to match(/no-store/)
    end
  end
end
