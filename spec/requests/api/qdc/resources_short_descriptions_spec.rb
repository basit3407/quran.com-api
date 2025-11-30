# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'QDC Resources with Short Descriptions', type: :request do
  let(:english_lang) { Language.find_by(iso_code: 'en') }
  let(:translation) { ResourceContent.approved.translations.one_verse.first }

  before do
    skip 'No approved translations available' unless translation
    skip 'English language not found' unless english_lang

    # Setup test data
    ShortDescription.create!(
      resource: translation,
      language: english_lang,
      description: 'Clear and easy'
    )
  end

  describe 'GET /api/qdc/resources/translations' do
    it 'returns translations with short descriptions' do
      get '/api/qdc/resources/translations'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      translation_data = json['translations'].find { |t| t['id'] == translation.id }

      expect(translation_data).not_to be_nil
      expect(translation_data['short_description']).to be_present
      expect(translation_data['short_description']['description']).to eq('Clear and easy')
    end
  end
end
