# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'QDC Resources country_language_preference', type: :request do
  describe 'GET /api/qdc/resources/country_language_preference' do
  let!(:test_lang) { Language.find_or_create_by!(iso_code: 'xx') { |l| l.name = 'Test Lang' } }
  let!(:other_lang) { Language.find_or_create_by!(iso_code: 'zz') { |l| l.name = 'Other Lang' } }

    let!(:global_test_pref) do
      CountryLanguagePreference.create!(user_device_language: 'xx', country: nil)
    end

    let!(:us_test_pref) do
      CountryLanguagePreference.create!(user_device_language: 'xx', country: 'US')
    end

    it 'returns global preference when country is omitted' do
  get '/api/qdc/resources/country_language_preference', params: { user_device_language: 'xx' }

      unless response.status == 200
        warn "DEBUG status=#{response.status} headers=#{response.headers.inspect} body=#{response.body}"
      end
      expect(response).to have_http_status(:ok)
  json = JSON.parse(response.body)
  expect(json['id']).to eq(global_test_pref.id)
    end

    it 'returns country-specific preference first when country provided' do
  get '/api/qdc/resources/country_language_preference', params: { user_device_language: 'xx', country: 'US' }

  expect(response).to have_http_status(:ok)
  json = JSON.parse(response.body)
  expect(json['id']).to eq(us_test_pref.id)
    end

    it 'falls back to global when country-specific not found' do
  get '/api/qdc/resources/country_language_preference', params: { user_device_language: 'xx', country: 'CA' }

  expect(response).to have_http_status(:ok)
  json = JSON.parse(response.body)
  expect(json['id']).to eq(global_test_pref.id)
    end

    it 'returns 404 when nothing matches' do
  get '/api/qdc/resources/country_language_preference', params: { user_device_language: 'zz' }

      expect(response).to have_http_status(:not_found)
    end

    it 'validates user_device_language presence' do
      get '/api/qdc/resources/country_language_preference'

      expect(response).to have_http_status(:bad_request)
    end

    it 'validates country code when provided' do
  get '/api/qdc/resources/country_language_preference', params: { user_device_language: 'xx', country: 'ZZ' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns qr_default_arabic_fonts as an array of numbers' do
      pref_with_fonts = CountryLanguagePreference.create!(
        user_device_language: 'xx',
        country: 'GB',
        qr_default_arabic_fonts: '1,2,3'
      )

      get '/api/qdc/resources/country_language_preference', params: { user_device_language: 'xx', country: 'GB' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['qr_default_arabic_fonts']).to eq([1, 2, 3])
    end

    it 'includes default_locale and qr_default_locale when present' do
      pref_with_locales = CountryLanguagePreference.create!(
        user_device_language: 'xx',
        country: 'DE',
        default_locale: 'xx',
        qr_default_locale: 'zz'
      )

      get '/api/qdc/resources/country_language_preference', params: { user_device_language: 'xx', country: 'DE' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json.dig('default_locale', 'iso_code')).to eq('xx')
      expect(json.dig('qr_default_locale', 'iso_code')).to eq('zz')
    end
  end
end
