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

    context 'language fallback behavior' do
      let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar') }

      before do
        # Create Arabic translations for reading1
        create(:localized_content,
          resource: @reading1,
          language: arabic,
          content_type: 'translation',
          text: 'أخيك (منصوب)'
        )

        # Create a shared explanation only in English
        @shared_explanation = create(:qiraat_reading_explanation, source: 'al-Alusi')
        create(:localized_content,
          resource: @shared_explanation,
          language: english,
          content_type: 'explanation',
          text: 'English only explanation')

        create(:qiraat_reading_explanation_membership,
          qiraat_reading: @reading1,
          qiraat_reading_explanation: @shared_explanation)

        # Create combined_translation only in English for the juncture
        create(:localized_content,
          resource: @juncture,
          language: english,
          content_type: 'combined_translation',
          text: 'English only combined translation')
      end

      it 'does not fall back to English for Arabic when content is missing' do
        get '/api/qdc/qiraat/matrix/by_verse/12:12', params: { language: 'ar' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        reading = json['junctures'].first['readings'].first

        # Arabic translation should be present (we created it)
        expect(reading['translation']).to eq('أخيك (منصوب)')

        # Explanation should NOT fall back to English (should be null/missing)
        expect(reading['explanation']).to be_nil

        # Combined translation/commentary should NOT fall back to English (should be null/missing)
        juncture = json['junctures'].first
        expect(juncture['combined_translation']).to be_nil
        expect(juncture['commentary']).to be_nil
      end

      it 'falls back to English for non-Arabic languages when content is missing' do
        french = Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr')

        get '/api/qdc/qiraat/matrix/by_verse/12:12', params: { language: french.iso_code }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        reading = json['junctures'].first['readings'].first
        juncture = json['junctures'].first

        # French should fall back to English when French content is missing
        expect(reading['translation']).to eq('your brother (accusative)')
        expect(reading['explanation']).to be_present
        expect(reading['explanation']['text']).to eq('English only explanation')
        expect(juncture['combined_translation']).to eq('English only combined translation')
        expect(juncture['commentary']).to eq('English only combined translation')
      end
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

    context 'language fallback behavior' do
      let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar') }

      before do
        # Create Arabic translations for reading1
        create(:localized_content,
          resource: @reading1,
          language: arabic,
          content_type: 'translation',
          text: 'أخيك (منصوب)'
        )
      end

      it 'does not fall back to English for Arabic when content is missing' do
        get '/api/qdc/qiraat/matrix/by_chapter/12', params: { language: 'ar', page: 1, per_page: 10 }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Find the reading with Arabic translation in the response
        juncture = json['junctures'].first
        reading = juncture['readings'].find { |r| r['translation'] == 'أخيك (منصوب)' }

        expect(reading).to be_present
        expect(reading['translation']).to eq('أخيك (منصوب)')
      end

      it 'falls back to English for non-Arabic languages when content is missing' do
        french = Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr')

        get '/api/qdc/qiraat/matrix/by_chapter/12', params: { language: french.iso_code, page: 1, per_page: 10 }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # French should fall back to English when French content is missing
        juncture = json['junctures'].first
        reading = juncture['readings'].first

        expect(reading['translation']).to eq('your brother (accusative)')
      end
    end
  end

  describe 'GET /api/qdc/qiraat/matrix/count_within_range' do
    before do
      # Create additional verses and junctures for range testing
      @verse2 = Verse.find_or_create_by!(chapter_id: 12, verse_number: 13) do |v|
        v.verse_key = '12:13'
        v.text_uthmani = 'قَالُوا يَا أَبَانَا مَا لَكَ لَا تَأْمَنَّا عَلَى يُوسُفَ'
      end

      # Create words for verse2
      @word2 = Word.find_or_create_by!(verse_id: @verse2.id, position: 1) do |w|
        w.text_uthmani = 'قَالُوا'
        w.char_type_name = 'word'
      end

      # Create a juncture for verse2
      @juncture2 = create(:qiraat_juncture, position: 2)
      @segment2 = create(:qiraat_juncture_segment,
        qiraat_juncture: @juncture2,
        verse: @verse2,
        start_word: @word2,
        end_word: @word2,
        position: 1
      )
      create(:qiraat_reading, qiraat_juncture: @juncture2, text_uthmani: 'قَالُوا')
    end

    context 'with valid parameters' do
      it 'returns juncture counts for verses within range' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:12', to: '12:13' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should return counts for both verses
        expect(json).to be_a(Hash)
        expect(json['12:12']).to eq(1)  # One approved juncture
        expect(json['12:13']).to eq(1)  # One approved juncture
      end

      it 'returns empty hash for range with no junctures' do
        # Create a verse without any junctures
        Verse.find_or_create_by!(chapter_id: 1, verse_number: 2) do |v|
          v.verse_key = '1:2'
          v.text_uthmani = 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ'
        end

        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '1:2', to: '1:2' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should return empty hash since no junctures exist for this verse
        expect(json).to eq({})
      end

      it 'returns correct count for single verse range' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:12', to: '12:12' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json).to be_a(Hash)
        expect(json['12:12']).to eq(1)
      end

      it 'handles ranges spanning multiple chapters' do
        # Create verse in chapter 1
        Verse.find_or_create_by!(chapter_id: 1, verse_number: 5) do |v|
          v.verse_key = '1:5'
          v.text_uthmani = 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ'
        end

        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '1:1', to: '12:12' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should only include verse 12:12 which has a juncture
        expect(json).to be_a(Hash)
        expect(json['12:12']).to eq(1)
      end
    end

    context 'with missing parameters' do
      it 'returns error when from parameter is missing' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { to: '12:13' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Missing required parameters')
        expect(json['error']['details']['required']).to include('from')
      end

      it 'returns error when to parameter is missing' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:12' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Missing required parameters')
        expect(json['error']['details']['required']).to include('to')
      end

      it 'returns error when both parameters are missing' do
        get '/api/qdc/qiraat/matrix/count_within_range'

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Missing required parameters')
        expect(json['error']['details']['required']).to match_array(['from', 'to'])
      end
    end

    context 'with invalid verse key format' do
      it 'returns error when from has invalid format' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: 'invalid', to: '12:13' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid verse_key format')
        expect(json['error']['details']['from']).to eq('invalid')
        expect(json['error']['details']['to']).to eq('12:13')
      end

      it 'returns error when to has invalid format' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:12', to: 'not-valid' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid verse_key format')
        expect(json['error']['details']['from']).to eq('12:12')
        expect(json['error']['details']['to']).to eq('not-valid')
      end

      it 'returns error when both have invalid format' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: 'abc', to: 'xyz' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid verse_key format')
      end

      it 'returns error for format without colon separator' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '1212', to: '1213' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
      end

      it 'accepts whitespace and strips it' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: ' 12:12 ', to: ' 12:13 ' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['12:12']).to eq(1)
      end
    end

    context 'with invalid verse keys' do
      it 'returns error when from references non-existent verse' do
        # Use a verse key that doesn't exist (beyond Quran range)
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '999:999', to: '12:13' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid verse keys')
      end

      it 'returns error when to references non-existent verse' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:12', to: '999:999' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid verse keys')
      end
    end

    context 'with invalid range' do
      it 'returns error when from verse comes after to verse' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:13', to: '12:12' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid range')
        expect(json['error']['message']).to include('from verse must come before to verse')
      end

      it 'returns error when from is in later chapter than to' do
        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:12', to: '1:1' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid range')
      end
    end

    context 'excluding unapproved junctures' do
      it 'only counts approved junctures' do
        # Create an unapproved juncture for verse 12:12
        unapproved_juncture = create(:qiraat_juncture, position: 99, approved: false)
        create(:qiraat_juncture_segment,
          qiraat_juncture: unapproved_juncture,
          verse: @verse,
          start_word: @word1,
          end_word: @word1,
          position: 1
        )

        get '/api/qdc/qiraat/matrix/count_within_range', params: { from: '12:12', to: '12:12' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should only count the approved juncture, not the unapproved one
        expect(json['12:12']).to eq(1)
      end
    end
  end
end
