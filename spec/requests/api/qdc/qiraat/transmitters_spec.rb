# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::Qiraat::Transmitters', type: :request do
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
      abbreviation: 'Nāfiʿ'
    )

    @reader2 = create(:qiraat_reader,
      name: 'Ibn Kathīr',
      abbreviation: 'Ibn Kathīr'
    )

    @transmitter1 = create(:qiraat_transmitter,
      qiraat_reader: @reader1,
      name: 'Warsh',
      abbreviation: 'Warsh',
      is_primary: true
    )

    @transmitter2 = create(:qiraat_transmitter,
      qiraat_reader: @reader1,
      name: 'Qālūn',
      abbreviation: 'Qālūn',
      is_primary: false
    )

    @transmitter3 = create(:qiraat_transmitter,
      qiraat_reader: @reader2,
      name: 'al-Bazzī',
      abbreviation: 'al-Bazzī',
      is_primary: true
    )

    create(:localized_content,
      resource: @transmitter1,
      language: english,
      content_type: 'bio',
      text: 'Warsh was a prominent transmitter of the Nāfiʿ reading.'
    )
  end

  describe 'GET /api/qdc/qiraat/transmitters' do
    it 'returns all transmitters' do
      get '/api/qdc/qiraat/transmitters'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['transmitters']).to be_an(Array)
      expect(json['transmitters'].length).to eq(3)
      expect(json['meta']['total']).to eq(3)
    end

    it 'returns transmitters in correct order by position' do
      get '/api/qdc/qiraat/transmitters'

      json = JSON.parse(response.body)
      positions = json['transmitters'].map { |t| t['position'] }

      expect(positions).to eq(positions.sort)
    end

    it 'includes reader information' do
      get '/api/qdc/qiraat/transmitters'

      json = JSON.parse(response.body)
      first_transmitter = json['transmitters'].first

      expect(first_transmitter['reader']).to be_present
      expect(first_transmitter['reader']['name']).to be_present
    end

    context 'with reader_id filter' do
      it 'filters transmitters by reader_id' do
        get '/api/qdc/qiraat/transmitters', params: { reader_id: @reader1.id }

        json = JSON.parse(response.body)

        expect(json['transmitters'].length).to eq(2)
        json['transmitters'].each do |t|
          expect(t['reader']['id']).to eq(@reader1.id)
        end
      end

      it 'returns empty array for reader with no transmitters' do
        reader_without_transmitters = create(:qiraat_reader, name: 'Test', abbreviation: 'T')
        get '/api/qdc/qiraat/transmitters', params: { reader_id: reader_without_transmitters.id }

        json = JSON.parse(response.body)

        expect(json['transmitters']).to eq([])
        expect(json['meta']['total']).to eq(0)
      end
    end

    it 'includes all required fields' do
      get '/api/qdc/qiraat/transmitters'

      json = JSON.parse(response.body)
      transmitter = json['transmitters'].first

      expect(transmitter['id']).to be_present
      expect(transmitter['name']).to be_present
      expect(transmitter['abbreviation']).to be_present
      expect(transmitter['position']).to be_present
      expect(transmitter['is_primary']).to be_in([true, false])
    end
  end

  describe 'GET /api/qdc/qiraat/transmitters/:id' do
    it 'returns detailed transmitter data' do
      get "/api/qdc/qiraat/transmitters/#{@transmitter1.id}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['transmitter']['id']).to eq(@transmitter1.id)
      expect(json['transmitter']['name']).to eq('Warsh')
      expect(json['transmitter']['bio']).to be_present
      expect(json['transmitter']['bio']['text']).to include('Warsh was a prominent transmitter')
    end

    it 'includes reader information' do
      get "/api/qdc/qiraat/transmitters/#{@transmitter1.id}"

      json = JSON.parse(response.body)

      expect(json['transmitter']['reader']).to be_present
      expect(json['transmitter']['reader']['name']).to eq('Nāfiʿ al-Madanī')
    end

    it 'returns error for non-existent transmitter' do
      get '/api/qdc/qiraat/transmitters/99999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('NOT_FOUND')
      expect(json['error']['message']).to include('not found')
    end
  end
end
