# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::Qiraat::Readers', type: :request do
  let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en') }

  before do
    # Clean up any existing data in correct dependency order
    LocalizedContent.delete_all
    QiraatReadingTranslationMembership.delete_all
    QiraatReadingTranslation.delete_all
    QiraatReadingExplanationMembership.delete_all
    QiraatReadingAttribution.delete_all
    QiraatReading.delete_all
    QiraatReadingExplanation.delete_all
    QiraatJunctureSegment.delete_all
    QiraatJuncture.delete_all
    QiraatTransmitter.delete_all
    QiraatReader.delete_all

    @reader1 = create(:qiraat_reader,
      name: 'Nāfiʿ al-Madanī',
      abbreviation: 'Nāfiʿ',
      death_year_hijri: 169
    )

    @reader2 = create(:qiraat_reader,
      name: 'Ibn Kathīr',
      abbreviation: 'Ibn Kathīr',
      death_year_hijri: 120
    )

    @transmitter1 = create(:qiraat_transmitter,
      qiraat_reader: @reader1,
      name: 'Warsh',
      abbreviation: 'Warsh',
      is_primary: true
    )

    create(:localized_content,
      resource: @reader1,
      language: english,
      content_type: 'bio',
      text: 'Nāfiʿ was a prominent scholar of Quranic recitation in Medina.'
    )
  end

  describe 'GET /api/qdc/qiraat/readers' do
    it 'returns all readers' do
      get '/api/qdc/qiraat/readers'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['readers']).to be_an(Array)
      expect(json['readers'].length).to eq(2)
      expect(json['meta']['total']).to eq(2)
    end

    it 'returns readers in correct order by position' do
      get '/api/qdc/qiraat/readers'

      json = JSON.parse(response.body)

      expect(json['readers'].first['abbreviation']).to eq('Nāfiʿ')
      expect(json['readers'].second['abbreviation']).to eq('Ibn Kathīr')
    end

    context 'with include parameter' do
      it 'includes transmitters when requested via include=transmitters' do
        get '/api/qdc/qiraat/readers', params: { include: 'transmitters' }

        json = JSON.parse(response.body)
        first_reader = json['readers'].first

        expect(first_reader['transmitters']).to be_an(Array)
        expect(first_reader['transmitters'].length).to eq(1)
        expect(first_reader['transmitters'].first['name']).to eq('Warsh')
      end

      it 'includes bio when requested via include=bio' do
        get '/api/qdc/qiraat/readers', params: { include: 'bio' }

        json = JSON.parse(response.body)
        first_reader = json['readers'].first

        expect(first_reader['bio']).to be_present
        expect(first_reader['bio']['text']).to include('Nāfiʿ was a prominent scholar')
      end

      it 'includes multiple relations when requested via include=transmitters,bio' do
        get '/api/qdc/qiraat/readers', params: { include: 'transmitters,bio' }

        json = JSON.parse(response.body)
        first_reader = json['readers'].first

        expect(first_reader['transmitters']).to be_an(Array)
        expect(first_reader['bio']).to be_present
      end
    end

    it 'includes all required fields' do
      get '/api/qdc/qiraat/readers'

      json = JSON.parse(response.body)
      reader = json['readers'].first

      expect(reader['id']).to be_present
      expect(reader['name']).to be_present
      expect(reader['abbreviation']).to be_present
      expect(reader['position']).to be_present
      expect(reader['death_year_hijri']).to be_present
    end
  end

  describe 'GET /api/qdc/qiraat/readers/:id' do
    it 'returns detailed reader data' do
      get "/api/qdc/qiraat/readers/#{@reader1.id}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['reader']['id']).to eq(@reader1.id)
      expect(json['reader']['name']).to eq('Nāfiʿ al-Madanī')
      expect(json['reader']['bio']).to be_present
      expect(json['reader']['bio']['text']).to include('Nāfiʿ was a prominent scholar')
    end

    it 'includes transmitters' do
      get "/api/qdc/qiraat/readers/#{@reader1.id}"

      json = JSON.parse(response.body)

      expect(json['reader']['transmitters']).to be_an(Array)
      expect(json['reader']['transmitters'].length).to eq(1)
    end

    it 'returns error for non-existent reader' do
      get '/api/qdc/qiraat/readers/99999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('NOT_FOUND')
      expect(json['error']['message']).to include('not found')
    end
  end

  describe 'language support' do
    let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar', name: 'Arabic', direction: 'rtl') }

    before do
      # Add Arabic localized name for reader1
      create(:localized_content,
        resource: @reader1,
        language: arabic,
        content_type: 'name',
        text: 'نافع المدني'
      )

      # Add Arabic bio for reader1
      create(:localized_content,
        resource: @reader1,
        language: arabic,
        content_type: 'bio',
        text: 'كان نافع عالماً بارزاً في قراءة القرآن في المدينة المنورة.'
      )
    end

    describe 'translated_name' do
      it 'returns Arabic name when language=ar' do
        get '/api/qdc/qiraat/readers', params: { language: 'ar' }

        json = JSON.parse(response.body)
        reader = json['readers'].find { |r| r['id'] == @reader1.id }

        expect(reader['translated_name']).to eq('نافع المدني')
      end

      it 'returns default name when language has no translation' do
        get '/api/qdc/qiraat/readers', params: { language: 'fr' }

        json = JSON.parse(response.body)
        reader = json['readers'].find { |r| r['id'] == @reader1.id }

        # Falls back to default name (no French or English localized name)
        expect(reader['translated_name']).to eq('Nāfiʿ al-Madanī')
      end

      it 'returns default name for reader without localized content' do
        get '/api/qdc/qiraat/readers', params: { language: 'ar' }

        json = JSON.parse(response.body)
        reader = json['readers'].find { |r| r['id'] == @reader2.id }

        # Reader2 has no Arabic name, falls back to default
        expect(reader['translated_name']).to eq('Ibn Kathīr')
      end
    end

    describe 'bio with fallback' do
      it 'returns Arabic bio when language=ar and include=bio' do
        get '/api/qdc/qiraat/readers', params: { language: 'ar', include: 'bio' }

        json = JSON.parse(response.body)
        reader = json['readers'].find { |r| r['id'] == @reader1.id }

        expect(reader['bio']['text']).to eq('كان نافع عالماً بارزاً في قراءة القرآن في المدينة المنورة.')
      end

      it 'falls back to English bio when requested language not available' do
        get '/api/qdc/qiraat/readers', params: { language: 'fr', include: 'bio' }

        json = JSON.parse(response.body)
        reader = json['readers'].find { |r| r['id'] == @reader1.id }

        # Falls back to English bio
        expect(reader['bio']['text']).to include('Nāfiʿ was a prominent scholar')
      end
    end
  end
end
