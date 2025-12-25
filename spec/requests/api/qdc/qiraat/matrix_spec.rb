# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::Qiraat::Matrix', type: :request do
  let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en') }

  before do
    # Clean up any existing qiraat data in correct dependency order
    QiraatReadingExplanationMembership.delete_all
    QiraatReadingTranslationMembership.delete_all
    QiraatReadingAttribution.delete_all
    QiraatReading.delete_all
    QiraatReadingExplanation.delete_all
    QiraatReadingTranslation.delete_all
    QiraatJunctureSegment.delete_all
    QiraatJuncture.delete_all
    QiratType.update_all(qiraat_transmitter_id: nil) # Clear FK references before deleting transmitters
    QiraatTransmitter.delete_all
    QiraatReader.delete_all

    # Create complete test data for Yusuf 12:12
    @chapter = Chapter.find_or_create_by!(id: 12, chapter_number: 12) do |c|
      c.name_simple = 'Yusuf'
      c.verses_count = 111
    end

    @verse = Verse.find_or_create_by!(chapter_id: 12, verse_number: 12) do |v|
      v.verse_key = '12:12'
      v.text_uthmani = 'أَرْسِلْهُ مَعَنَا غَدًا يَرْتَعْ وَيَلْعَبْ وَإِنَّا لَهُ لَحَافِظُونَ'
    end

    # Create words for the verse
    @word1 = Word.find_or_create_by!(verse_id: @verse.id, position: 1) do |w|
      w.text_uthmani = 'أَخَاكَ'
      w.text_imlaei = 'أخاك'
      w.text_qpc_hafs = 'أَخَاكَ'
      w.char_type_name = 'word'
    end

    @reader1 = create(:qiraat_reader)
    @reader2 = create(:qiraat_reader)

    @transmitter1 = create(:qiraat_transmitter,
      qiraat_reader: @reader1,
      is_primary: true
    )

    @juncture = create(:qiraat_juncture)

    # Create the segment that links the juncture to the verse via words
    @segment = create(:qiraat_juncture_segment,
      qiraat_juncture: @juncture,
      verse: @verse,
      start_word: @word1,
      end_word: @word1,
      position: 1
    )

    @reading1 = create(:qiraat_reading,
      qiraat_juncture: @juncture,
      text_uthmani: 'أَخَاكَ'
    )

    @reading2 = create(:qiraat_reading,
      qiraat_juncture: @juncture,
      text_uthmani: 'أَخِيكَ'
    )

    # Create attributions
    create(:qiraat_reading_attribution,
      qiraat_reading: @reading1,
      qiraat_reader: @reader1,
      qiraat_transmitter: nil
    )

    create(:qiraat_reading_attribution,
      qiraat_reading: @reading2,
      qiraat_reader: @reader2,
      qiraat_transmitter: nil
    )

    # Add localized content
    create(:localized_content,
      resource: @reading1,
      language: english,
      content_type: 'translation',
      text: 'your brother (accusative)'
    )

    create(:localized_content,
      resource: @reading1,
      language: english,
      content_type: 'transliteration',
      text: 'akhaaka'
    )
  end

  describe 'GET /api/qdc/qiraat/matrix/by_verse/:verse_key' do
    it 'returns complete matrix data for a verse' do
      get '/api/qdc/qiraat/matrix/by_verse/12:12'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Check verse data - now uses 'text' instead of 'text_uthmani'
      expect(json['verse']['verse_key']).to eq('12:12')
      expect(json['verse']['chapter_number']).to eq(12)
      expect(json['verse']['verse_number']).to eq(12)
      expect(json['verse']['text']).to be_present
      expect(json['verse']['text_field']).to eq('text_uthmani')

      # Check readers array
      expect(json['readers']).to be_an(Array)
      expect(json['readers'].length).to be >= 2

      # Check transmitters array
      expect(json['transmitters']).to be_an(Array)

      # Check junctures with readings
      expect(json['junctures']).to be_an(Array)
      expect(json['junctures'].length).to eq(1)

      juncture = json['junctures'].first
      expect(juncture['readings']).to be_an(Array)
      expect(juncture['readings'].length).to eq(2)

      # Check matrix data in readings
      reading = juncture['readings'].first
      expect(reading['matrix']).to be_a(Hash)
      expect(reading['matrix']['readers']).to be_an(Array)
      expect(reading['matrix']['cells']).to be_an(Array)
      # Reading should have 'text' field
      expect(reading['text']).to be_present
    end

    it 'returns error for invalid verse key format' do
      get '/api/qdc/qiraat/matrix/by_verse/invalid'

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('INVALID_PARAMETER')
    end

    it 'returns not found for verse without qiraat data' do
      other_verse = Verse.find_or_create_by!(chapter_id: 1, verse_number: 1) do |v|
        v.verse_key = '1:1'
        v.text_uthmani = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'
      end

      get '/api/qdc/qiraat/matrix/by_verse/1:1'

      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('NOT_FOUND')
    end

    it 'excludes unapproved junctures from results' do
      # Create an unapproved juncture for the same verse
      unapproved_juncture = create(:qiraat_juncture, position: 99, approved: false)
      create(:qiraat_juncture_segment,
        qiraat_juncture: unapproved_juncture,
        verse: @verse,
        start_word: @word1,
        end_word: @word1,
        position: 1
      )
      create(:qiraat_reading, qiraat_juncture: unapproved_juncture, text_uthmani: 'unapproved')

      get '/api/qdc/qiraat/matrix/by_verse/12:12'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Should only have the 1 approved juncture, not the unapproved one
      expect(json['junctures'].length).to eq(1)
      juncture_ids = json['junctures'].map { |j| j['id'] }
      expect(juncture_ids).not_to include(unapproved_juncture.id)

      # Positive test: approved juncture should be included
      expect(juncture_ids).to include(@juncture.id)
    end

    it 'includes translations and transliterations' do
      get '/api/qdc/qiraat/matrix/by_verse/12:12'

      json = JSON.parse(response.body)
      reading = json['junctures'].first['readings'].first

      expect(reading['translation']).to eq('your brother (accusative)')
      expect(reading['transliteration']).to eq('akhaaka')
    end

    context 'with shared explanations' do
      before do
        # Create a shared explanation for readings
        @shared_explanation = create(:qiraat_reading_explanation, source: 'al-Alusi')
        create(:localized_content,
               resource: @shared_explanation,
               language: english,
               content_type: 'explanation',
               text: 'Shared explanation text for multiple readings')

        # Attach to both readings
        create(:qiraat_reading_explanation_membership,
               qiraat_reading: @reading1,
               qiraat_reading_explanation: @shared_explanation)
        create(:qiraat_reading_explanation_membership,
               qiraat_reading: @reading2,
               qiraat_reading_explanation: @shared_explanation)
      end

      it 'returns shared explanations array' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12'

        json = JSON.parse(response.body)
        reading = json['junctures'].first['readings'].first

        expect(reading['explanations']).to be_an(Array)
        expect(reading['explanations'].first['text']).to eq('Shared explanation text for multiple readings')
        expect(reading['explanations'].first['source']).to eq('al-Alusi')
      end

      it 'returns backward-compatible explanation object' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12'

        json = JSON.parse(response.body)
        reading = json['junctures'].first['readings'].first

        expect(reading['explanation']).to be_a(Hash)
        expect(reading['explanation']['text']).to eq('Shared explanation text for multiple readings')
        expect(reading['explanation']['source']).to eq('al-Alusi')
      end
    end

    it 'includes meta information' do
      get '/api/qdc/qiraat/matrix/by_verse/12:12'

      json = JSON.parse(response.body)

      expect(json['meta']).to be_a(Hash)
      expect(json['meta']['language']).to eq('en')
      expect(json['meta']['text_field']).to eq('text_uthmani')
      expect(json['meta']['total_junctures']).to eq(1)
      expect(json['meta']['generated_at']).to be_present
    end

    context 'with text_field parameter' do
      before do
        # Update verse with different text fields
        @verse.update(
          text_uthmani: 'أَرْسِلْهُ مَعَنَا غَدًا',
          text_imlaei: 'ارسله معنا غدا',
          text_qpc_hafs: 'ﭐﺭ۟ﺳِﻠۡﻪُ ﻣَﻌَﻨَﺎ ﻏَﺪٗﺍ'
        )
      end

      it 'defaults to text_uthmani when no text_field specified' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12'

        json = JSON.parse(response.body)
        expect(json['verse']['text_field']).to eq('text_uthmani')
        expect(json['verse']['text']).to eq(@verse.text_uthmani)
        expect(json['meta']['text_field']).to eq('text_uthmani')
      end

      it 'returns text_qpc_hafs when specified' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12', params: { text_field: 'text_qpc_hafs' }

        json = JSON.parse(response.body)
        expect(json['verse']['text_field']).to eq('text_qpc_hafs')
        expect(json['verse']['text']).to eq(@verse.text_qpc_hafs)
        expect(json['meta']['text_field']).to eq('text_qpc_hafs')
      end

      it 'returns text_imlaei when specified' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12', params: { text_field: 'text_imlaei' }

        json = JSON.parse(response.body)
        expect(json['verse']['text_field']).to eq('text_imlaei')
        expect(json['verse']['text']).to eq(@verse.text_imlaei)
        expect(json['meta']['text_field']).to eq('text_imlaei')
      end

      it 'normalizes text_field without prefix' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12', params: { text_field: 'qpc_hafs' }

        json = JSON.parse(response.body)
        expect(json['verse']['text_field']).to eq('text_qpc_hafs')
        expect(json['meta']['text_field']).to eq('text_qpc_hafs')
      end

      it 'falls back to text_uthmani for invalid text_field' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12', params: { text_field: 'invalid_field' }

        json = JSON.parse(response.body)
        expect(json['verse']['text_field']).to eq('text_uthmani')
        expect(json['verse']['text']).to eq(@verse.text_uthmani)
        expect(json['meta']['text_field']).to eq('text_uthmani')
      end
    end

    it 'caches the response', skip: 'Caching not yet implemented in controller' do
      # First request
      get '/api/qdc/qiraat/matrix/by_verse/12:12'
      expect(response).to have_http_status(:success)

      # Modify data
      @reading1.update(text_uthmani: 'MODIFIED')

      # Second request should return cached data
      get '/api/qdc/qiraat/matrix/by_verse/12:12'
      json = JSON.parse(response.body)

      # Should still have old value due to caching
      reading = json['junctures'].first['readings'].first
      expect(reading['text_uthmani']).not_to eq('MODIFIED')

      # Clear cache
      Rails.cache.clear

      # Now should get updated value
      get '/api/qdc/qiraat/matrix/by_verse/12:12'
      json = JSON.parse(response.body)
      reading = json['junctures'].first['readings'].first
      expect(reading['text_uthmani']).to eq('MODIFIED')
    end
  end

  describe 'GET /api/qdc/qiraat/matrix/by_chapter/:chapter_number' do
    it 'returns paginated matrix data for a chapter' do
      get '/api/qdc/qiraat/matrix/by_chapter/12', params: { page: 1, per_page: 10 }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Check chapter data
      expect(json['chapter']['chapter_number']).to eq(12)
      expect(json['chapter']['name_simple']).to eq('Yusuf')

      # Check pagination
      expect(json['pagination']).to be_a(Hash)
      expect(json['pagination']['current_page']).to eq(1)
      expect(json['pagination']['per_page']).to eq(10)
    end

    it 'returns error for non-existent chapter' do
      get '/api/qdc/qiraat/matrix/by_chapter/999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('NOT_FOUND')
    end
  end
end
