# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::Qiraat::Junctures', type: :request do
  let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en') }

  before do
    # Clean up any existing qiraat data in correct dependency order
    # First delete join tables and tables with foreign keys
    QiraatReadingTranslationMembership.delete_all
    QiraatReadingExplanationMembership.delete_all
    QiraatReadingAttribution.delete_all
    QiraatReading.delete_all
    QiraatReadingTranslation.delete_all
    QiraatReadingExplanation.delete_all
    QiraatJunctureSegment.delete_all
    QiraatJuncture.delete_all
    QiratType.update_all(qiraat_transmitter_id: nil) # Clear FK references before deleting transmitters
    QiraatTransmitter.delete_all
    QiraatReader.delete_all

    @chapter = Chapter.find_or_create_by!(id: 12, chapter_number: 12) do |c|
      c.name_simple = 'Yusuf'
      c.verses_count = 111
    end

    @verse = Verse.find_or_create_by!(chapter_id: 12, verse_number: 12) do |v|
      v.verse_key = '12:12'
      v.text_uthmani = 'أَرْسِلْهُ مَعَنَا غَدًا يَرْتَعْ وَيَلْعَبْ'
    end

    # Create words for the verse
    @word1 = Word.find_or_create_by!(verse_id: @verse.id, position: 3) do |w|
      w.text_uthmani = 'غَدًا'
      w.text_imlaei = 'غدا'
      w.text_qpc_hafs = 'غَدًا'
      w.char_type_name = 'word'
    end

    @word2 = Word.find_or_create_by!(verse_id: @verse.id, position: 4) do |w|
      w.text_uthmani = 'يَرْتَعْ'
      w.text_imlaei = 'يرتع'
      w.text_qpc_hafs = 'يَرْتَعْ'
      w.char_type_name = 'word'
    end

    @juncture1 = create(:qiraat_juncture, position: 1)
    @juncture2 = create(:qiraat_juncture, position: 2)

    # Create segments that link junctures to the verse via words
    @segment1 = create(:qiraat_juncture_segment,
      qiraat_juncture: @juncture1,
      verse: @verse,
      start_word: @word1,
      end_word: @word1,
      position: 1
    )

    @segment2 = create(:qiraat_juncture_segment,
      qiraat_juncture: @juncture2,
      verse: @verse,
      start_word: @word2,
      end_word: @word2,
      position: 1
    )

    @reading1 = create(:qiraat_reading,
      qiraat_juncture: @juncture1,
      text_uthmani: 'غَدًا',
      position: 1
    )

    create(:localized_content,
      resource: @juncture1,
      language: english,
      content_type: 'explanation',
      text: 'Variation in pronunciation of "tomorrow"'
    )
  end

  describe 'GET /api/qdc/qiraat/junctures/by_verse/:verse_key' do
    it 'returns all junctures for a verse' do
      get '/api/qdc/qiraat/junctures/by_verse/12:12'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['verse']['verse_key']).to eq('12:12')
      expect(json['junctures'].length).to eq(2)
      expect(json['meta']['total_junctures']).to eq(2)
    end

    it 'returns junctures in order' do
      get '/api/qdc/qiraat/junctures/by_verse/12:12'

      json = JSON.parse(response.body)
      positions = json['junctures'].map { |j| j['position'] }

      expect(positions).to eq([1, 2])
    end

    it 'includes readings when requested' do
      get '/api/qdc/qiraat/junctures/by_verse/12:12', params: { include: 'readings' }

      json = JSON.parse(response.body)
      first_juncture = json['junctures'].first

      expect(first_juncture['readings']).to be_an(Array)
      expect(first_juncture['readings'].length).to eq(1)
    end

    it 'includes explanation when available' do
      get '/api/qdc/qiraat/junctures/by_verse/12:12'

      json = JSON.parse(response.body)
      first_juncture = json['junctures'].first

      expect(first_juncture['explanation']).to eq('Variation in pronunciation of "tomorrow"')
    end

    it 'returns error for non-existent verse' do
      get '/api/qdc/qiraat/junctures/by_verse/999:999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('NOT_FOUND')
    end

    context 'with unapproved junctures' do
      before do
        @unapproved_juncture = create(:qiraat_juncture, position: 3, approved: false)
        create(:qiraat_juncture_segment,
          qiraat_juncture: @unapproved_juncture,
          verse: @verse,
          start_word: @word1,
          end_word: @word1,
          position: 1
        )
      end

      it 'only returns approved junctures' do
        get '/api/qdc/qiraat/junctures/by_verse/12:12'

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should only have the 2 approved junctures, not the unapproved one
        expect(json['junctures'].length).to eq(2)
        juncture_ids = json['junctures'].map { |j| j['id'] }
        expect(juncture_ids).not_to include(@unapproved_juncture.id)
      end

      it 'returns 404 when accessing unapproved juncture directly' do
        get "/api/qdc/qiraat/junctures/#{@unapproved_juncture.id}"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']['code']).to eq('NOT_FOUND')
      end

      it 'includes approved junctures in results' do
        get '/api/qdc/qiraat/junctures/by_verse/12:12'

        json = JSON.parse(response.body)
        juncture_ids = json['junctures'].map { |j| j['id'] }

        # Approved junctures should be included
        expect(juncture_ids).to include(@juncture1.id)
        expect(juncture_ids).to include(@juncture2.id)
      end

      it 'returns approved juncture when accessed directly' do
        get "/api/qdc/qiraat/junctures/#{@juncture1.id}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['juncture']['id']).to eq(@juncture1.id)
      end
    end
  end

  describe 'GET /api/qdc/qiraat/junctures/by_chapter/:chapter_number' do
    it 'returns paginated junctures for a chapter' do
      get '/api/qdc/qiraat/junctures/by_chapter/12', params: { page: 1, per_page: 20 }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['chapter']['chapter_number']).to eq(12)
      expect(json['junctures']).to be_an(Array)
      expect(json['pagination']).to be_a(Hash)
    end

    it 'returns error for non-existent chapter' do
      get '/api/qdc/qiraat/junctures/by_chapter/999'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/qdc/qiraat/junctures/:id' do
    it 'returns detailed juncture data' do
      get "/api/qdc/qiraat/junctures/#{@juncture1.id}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['juncture']['id']).to eq(@juncture1.id)
      expect(json['juncture']['verse_key']).to eq('12:12')
      expect(json['juncture']['readings']).to be_an(Array)
    end

    it 'returns error for non-existent juncture' do
      get '/api/qdc/qiraat/junctures/99999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('NOT_FOUND')
    end
  end
end
