# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SunnahApi do
  let(:instance) { described_class.instance }

  before do
    # Set required environment variables
    ENV['SUNNAH_API_KEY'] = 'test-api-key'
    ENV['SUNNAH_API_URL'] = 'https://api.sunnah.com/v1'
  end

  after do
    ENV.delete('SUNNAH_API_KEY')
    ENV.delete('SUNNAH_API_URL')
  end

  describe '#hadith_by_urns_raw' do
    let(:success_response) do
      {
        'count' => 2,
        'missing' => [],
        'data' => [
          {
            'collection' => 'bukhari',
            'bookNumber' => '1',
            'chapterId' => '1',
            'hadithNumber' => '1',
            'urn' => 305,
            'hadith' => [
              {
                'lang' => 'en',
                'chapterNumber' => '1',
                'chapterTitle' => 'Revelation',
                'body' => 'Narrated Umar bin Al-Khattab:...'
              }
            ]
          },
          {
            'collection' => 'muslim',
            'bookNumber' => '1',
            'chapterId' => '2',
            'hadithNumber' => '2',
            'urn' => 306,
            'hadith' => [
              {
                'lang' => 'en',
                'chapterNumber' => '2',
                'chapterTitle' => 'Faith',
                'body' => 'Narrated Abdullah bin Amr:...'
              }
            ]
          }
        ]
      }
    end

    context 'with successful response' do
      before do
        allow(Faraday).to receive(:get).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )
      end

      it 'returns the raw response from the API' do
        result = instance.hadith_by_urns_raw('305,306')
        expect(result).to eq(success_response)
      end

      it 'accepts URNs as comma-separated string' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/v1/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw('305,306')
      end

      it 'accepts URNs as array of strings' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/v1/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw(['305', '306'])
      end

      it 'accepts URNs as array of integers' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/v1/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw([305, 306])
      end

      it 'accepts single URN as string' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/v1/hadiths/urns',
          { urns: '305' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump({ 'count' => 1, 'missing' => [], 'data' => [] }))
        )

        instance.hadith_by_urns_raw('305')
      end

      it 'normalizes and trims whitespace from URNs' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/v1/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw([' 305 ', ' 306 '])
      end

      it 'filters out empty values' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/v1/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw(['305', '', nil, '306', ' '])
      end
    end

    context 'with error responses' do
      it 'handles 400 Bad Request' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 400, body: 'Bad Request')
        )

        result = instance.hadith_by_urns_raw('invalid')
        expect(result).to eq({ 'status' => 400, 'message' => 'Bad Request.' })
      end

      it 'handles 401 Unauthorized' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 401, body: 'Unauthorized')
        )

        result = instance.hadith_by_urns_raw('305')
        expect(result).to eq({ 'status' => 401, 'message' => 'Unauthorized.' })
      end

      it 'handles 403 Forbidden' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 403, body: 'Forbidden')
        )

        result = instance.hadith_by_urns_raw('305')
        expect(result).to eq({ 'status' => 403, 'message' => 'Forbidden.' })
      end

      it 'handles 404 Not Found' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 404, body: 'Not Found')
        )

        result = instance.hadith_by_urns_raw('305')
        expect(result).to eq({ 'status' => 404, 'message' => 'Not Found.' })
      end

      it 'handles 429 Too Many Requests' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 429, body: 'Too Many Requests')
        )

        result = instance.hadith_by_urns_raw('305')
        expect(result).to eq({ 'status' => 429, 'message' => 'Too Many Requests.' })
      end

      it 'handles 500 Internal Server Error' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 500, body: 'Internal Server Error')
        )

        result = instance.hadith_by_urns_raw('305')
        expect(result).to eq({ 'status' => 500, 'message' => 'Internal Server Error.' })
      end

      it 'handles unknown error codes' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 418, body: "I'm a teapot")
        )

        result = instance.hadith_by_urns_raw('305')
        expect(result).to eq({ 'status' => 418, 'message' => 'Request failed.' })
      end
    end

    context 'with empty or nil URNs' do
      it 'returns error when URNs are empty string' do
        result = instance.hadith_by_urns_raw('')
        expect(result).to eq({ 'status' => 400, 'message' => 'urns is required' })
      end

      it 'returns error when URNs are empty array' do
        result = instance.hadith_by_urns_raw([])
        expect(result).to eq({ 'status' => 400, 'message' => 'urns is required' })
      end

      it 'returns error when URNs are nil' do
        result = instance.hadith_by_urns_raw(nil)
        expect(result).to eq({ 'status' => 400, 'message' => 'urns is required' })
      end

      it 'returns error when URNs contain only empty strings' do
        result = instance.hadith_by_urns_raw(['', ' ', ''])
        expect(result).to eq({ 'status' => 400, 'message' => 'urns is required' })
      end

      it 'does not make API call when URNs are empty' do
        expect(Faraday).not_to receive(:get)
        instance.hadith_by_urns_raw('')
      end
    end

    context 'with missing URNs in response' do
      let(:partial_response) do
        {
          'count' => 1,
          'missing' => [306],
          'data' => [
            {
              'collection' => 'bukhari',
              'bookNumber' => '1',
              'chapterId' => '1',
              'hadithNumber' => '1',
              'urn' => 305,
              'hadith' => []
            }
          ]
        }
      end

      it 'returns response with missing URNs' do
        allow(Faraday).to receive(:get).and_return(
          double(status: 200, body: Oj.dump(partial_response))
        )

        result = instance.hadith_by_urns_raw('305,306')
        expect(result['missing']).to eq([306])
        expect(result['count']).to eq(1)
      end
    end
  end

  describe '#hadith_by_urns' do
    let(:bukhari_collection) do
      {
        'name' => 'bukhari',
        'collection' => [
          { 'lang' => 'en', 'title' => 'Sahih al-Bukhari', 'shortIntro' => '...' },
          { 'lang' => 'ar', 'title' => 'صحيح البخاري', 'shortIntro' => '...' }
        ]
      }
    end

    let(:multi_language_response) do
      {
        'count' => 1,
        'missing' => [],
        'data' => [
          {
            'collection' => 'bukhari',
            'bookNumber' => '1',
            'chapterId' => '1',
            'hadithNumber' => '1',
            'urn' => 305,
            'hadith' => [
              {
                'lang' => 'en',
                'chapterNumber' => '1',
                'chapterTitle' => 'Revelation',
                'body' => 'Narrated Umar bin Al-Khattab in English...',
                'urn' => 31,
                'grades' => [
                  { 'graded_by' => 'Ahmad Muhammad Shakir', 'grade' => 'Sahih' },
                  { 'graded_by' => 'Another Scholar', 'grade' => 'Hasan' }
                ]
              },
              {
                'lang' => 'ar',
                'chapterNumber' => '1',
                'chapterTitle' => 'Ø§Ù„ÙˆØ­ÙŠ',
                'body' => 'Ø­Ø¯Ø«Ù†Ø§ Ø¹Ù…Ø± Ø¨Ù† Ø§Ù„Ø®Ø·Ø§Ø¨ Ø¨Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©...',
                'urn' => 32,
                'grades' => [
                  { 'graded_by' => 'Ø§Ù„Ø¹Ù„Ù…Ø§Ø¡', 'grade' => 'ØµØ­ÙŠØ­' }
                ]
              }
            ]
          }
        ]
      }
    end

    context 'with language: :en (default)' do
      before do
        allow(Faraday).to receive(:get).and_return(
          double(status: 200, body: Oj.dump(multi_language_response))
        )
        allow(instance).to receive(:get_collection).with('bukhari').and_return(bukhari_collection)
      end

      it 'flattens only body, urn and combines grades by default' do
        result = instance.hadith_by_urns('305')

        expect(result['data'].first).to include(
          'collection' => 'bukhari',
          'bookNumber' => '1',
          'chapterId' => '1',
          'hadithNumber' => '1',
          'urn' => 305
        )

        # Should only have body and urn from hadith, not chapterNumber or chapterTitle
        expect(result['data'].first).to include('en_body' => 'Narrated Umar bin Al-Khattab in English...')
        expect(result['data'].first).to include('en_urn' => 31)
        expect(result['data'].first).to include('ar_body' => 'Ø­Ø¯Ø«Ù†Ø§ Ø¹Ù…Ø± Ø¨Ù† Ø§Ù„Ø®Ø·Ø§Ø¨ Ø¨Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©...')
        expect(result['data'].first).to include('ar_urn' => 32)

        # Should NOT have chapterNumber or chapterTitle
        expect(result['data'].first).not_to have_key('en_chapterNumber')
        expect(result['data'].first).not_to have_key('en_chapterTitle')
        expect(result['data'].first).not_to have_key('ar_chapterNumber')
        expect(result['data'].first).not_to have_key('ar_chapterTitle')

        # Should have combined grades from non-Arabic hadith objects only (no lang field)
        grades = result['data'].first['grades']
        expect(grades.size).to eq(2)
        expect(grades).to include({ 'grade' => 'Sahih', 'gradeBy' => 'Ahmad Muhammad Shakir' })
        expect(grades).to include({ 'grade' => 'Hasan', 'gradeBy' => 'Another Scholar' })
        expect(grades.none? { |g| g.key?('lang') }).to eq(true)

        # Hadith array should be removed, grades array should be present
        expect(result['data'].first).not_to have_key('hadith')
        expect(result['data'].first).to have_key('grades')

        # Should have collection name
        expect(result['data'].first).to include('name' => 'Sahih al-Bukhari')
      end

      it 'preserves other non-hadith fields' do
        result = instance.hadith_by_urns('305')

        expect(result['data'].first['collection']).to eq('bukhari')
        expect(result['data'].first['bookNumber']).to eq('1')
        expect(result['data'].first['chapterId']).to eq('1')
        expect(result['data'].first['hadithNumber']).to eq('1')
        expect(result['data'].first['name']).to eq('Sahih al-Bukhari')
      end
    end

    context 'with language: :ar' do
      before do
        allow(Faraday).to receive(:get).and_return(
          double(status: 200, body: Oj.dump(multi_language_response))
        )
        allow(instance).to receive(:get_collection).with('bukhari').and_return(bukhari_collection)
      end

      it 'flattens only Arabic language data and filters grades to Arabic only (no lang field)' do
        result = instance.hadith_by_urns('305', language: :ar)

        # Should have only Arabic body and urn
        expect(result['data'].first).to include('ar_body' => 'Ø­Ø¯Ø«Ù†Ø§ Ø¹Ù…Ø± Ø¨Ù† Ø§Ù„Ø®Ø·Ø§Ø¨ Ø¨Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©...')
        expect(result['data'].first).to include('ar_urn' => 32)

        # Grades should be filtered to Arabic only (no lang field)
        expect(result['data'].first['grades']).to match_array([
          { 'grade' => 'ØµØ­ÙŠØ­', 'gradeBy' => 'Ø§Ù„Ø¹Ù„Ù…Ø§Ø¡' }
        ])

        # Should not have English prefixes
        expect(result['data'].first).not_to have_key('en_body')
        expect(result['data'].first).not_to have_key('en_urn')

        # Should have Arabic collection name
        expect(result['data'].first).to include('name' => 'صحيح البخاري')
      end

      it 'handles string language parameter' do
        result = instance.hadith_by_urns('305', language: 'ar')

        expect(result['data'].first).to include('ar_body')
        expect(result['data'].first).not_to have_key('en_body')
        expect(result['data'].first).to include('name' => 'صحيح البخاري')
      end
    end

    context 'with error response from raw method' do
      before do
        allow(Faraday).to receive(:get).and_return(
          double(status: 401, body: 'Unauthorized')
        )
      end

      it 'returns error response unchanged' do
        result = instance.hadith_by_urns('305')
        expect(result).to eq({ 'status' => 401, 'message' => 'Unauthorized.' })
      end
    end

    context 'with non-Array data in response' do
      before do
        allow(Faraday).to receive(:get).and_return(
          double(status: 200, body: Oj.dump({ 'data' => 'not an array' }))
        )
      end

      it 'returns response unchanged when data is not an array' do
        result = instance.hadith_by_urns('305')
        expect(result).to eq({ 'data' => 'not an array' })
      end
    end

    context 'with non-Hash response' do
      before do
        allow(Faraday).to receive(:get).and_return(
          double(status: 200, body: Oj.dump('string response'))
        )
      end

      it 'returns response unchanged when not a Hash' do
        result = instance.hadith_by_urns('305')
        expect(result).to eq('string response')
      end
    end
  end

  describe 'flatten_hadith_item (private method)' do
    let(:item_with_hadith) do
      {
        'collection' => 'bukhari',
        'urn' => 305,
        'hadith' => [
          {
            'lang' => 'en',
            'chapterNumber' => '1',
            'chapterTitle' => 'Revelation',
            'body' => 'English text',
            'urn' => 31,
            'grades' => [
              { 'graded_by' => 'Scholar 1', 'grade' => 'Sahih' },
              { 'graded_by' => 'Scholar 2', 'grade' => 'Hasan' }
            ]
          },
          {
            'lang' => 'ar',
            'chapterNumber' => '1',
            'chapterTitle' => 'Ø§Ù„ÙˆØ­ÙŠ',
            'body' => 'Arabic text',
            'urn' => 32,
            'grades' => [
              { 'graded_by' => 'Ø¹Ø§Ù„Ù…', 'grade' => 'ØµØ­ÙŠØ­' }
            ]
          }
        ]
      }
    end

    it 'flattens only body, urn and combines grades by language' do
      # Use send to call private method for testing
      result = instance.send(:flatten_hadith_item, item_with_hadith)

      # Should only have body and urn
      expect(result).to include('en_body' => 'English text')
      expect(result).to include('en_urn' => 31)
      expect(result).to include('ar_body' => 'Arabic text')
      expect(result).to include('ar_urn' => 32)

      # Should NOT have chapterNumber or chapterTitle
      expect(result).not_to have_key('en_chapterNumber')
      expect(result).not_to have_key('en_chapterTitle')
      expect(result).not_to have_key('ar_chapterNumber')
      expect(result).not_to have_key('ar_chapterTitle')

      # Should have combined grades from non-Arabic hadith objects only (no lang field)
      expect(result['grades']).to match_array([
        { 'grade' => 'Sahih', 'gradeBy' => 'Scholar 1' },
        { 'grade' => 'Hasan', 'gradeBy' => 'Scholar 2' }
      ])
    end

    it 'removes the hadith array after flattening and keeps grades array' do
      result = instance.send(:flatten_hadith_item, item_with_hadith)
      expect(result).not_to have_key('hadith')
      expect(result).to have_key('grades') # grades should be present as new format
    end

    it 'preserves other keys' do
      result = instance.send(:flatten_hadith_item, item_with_hadith)
      expect(result['collection']).to eq('bukhari')
      expect(result['urn']).to eq(305)
    end

    it 'includes all languages and filters grades when language is en' do
      result = instance.send(:flatten_hadith_item, item_with_hadith, language: 'en')

      # When language is 'en', it should include all languages for body/urn
      expect(result).to have_key('en_body')
      expect(result).to have_key('en_urn')
      expect(result).to have_key('ar_body')
      expect(result).to have_key('ar_urn')
      expect(result).to have_key('grades')
      # When language is 'en', it should include English grades only (not Arabic)
      expect(result['grades']).to match_array([
        { 'grade' => 'Sahih', 'gradeBy' => 'Scholar 1' },
        { 'grade' => 'Hasan', 'gradeBy' => 'Scholar 2' }
      ])
      # No lang field in grades
      expect(result['grades'].none? { |g| g.key?('lang') }).to eq(true)
    end

    it 'filters grades to Arabic only when language is ar' do
      result = instance.send(:flatten_hadith_item, item_with_hadith, language: 'ar')

      expect(result).to have_key('ar_body')
      expect(result).to have_key('ar_urn')
      expect(result).to have_key('grades')
      # When language is 'ar', it should include Arabic grades only
      expect(result['grades']).to match_array([
        { 'grade' => 'ØµØ­ÙŠØ­', 'gradeBy' => 'Ø¹Ø§Ù„Ù…' }
      ])
      # No lang field in grades
      expect(result['grades'].none? { |g| g.key?('lang') }).to eq(true)
      expect(result).not_to have_key('en_body')
      expect(result).not_to have_key('en_urn')
    end

    it 'handles empty hadith array' do
      item = { 'urn' => 305, 'hadith' => [] }
      result = instance.send(:flatten_hadith_item, item)

      expect(result).to eq('urn' => 305)
    end

    it 'handles nil hadith' do
      item = { 'urn' => 305, 'hadith' => nil }
      result = instance.send(:flatten_hadith_item, item)

      expect(result).to eq('urn' => 305)
    end

    it 'handles non-Hash item' do
      result = instance.send(:flatten_hadith_item, 'string')
      expect(result).to eq('string')
    end

    it 'skips hadith entries that are not Hash' do
      item = {
        'urn' => 305,
        'hadith' => ['not a hash', { 'lang' => 'en', 'body' => 'valid', 'urn' => 31, 'grades' => [] }]
      }
      result = instance.send(:flatten_hadith_item, item)

      expect(result).to include('en_body' => 'valid')
      expect(result).to include('en_urn' => 31)
    end

    it 'handles grades without graded_by field' do
      item = {
        'urn' => 305,
        'hadith' => [
          {
            'lang' => 'en',
            'body' => 'text',
            'grades' => [
              { 'grade' => 'Sahih' } # no graded_by field
            ]
          }
        ]
      }
      result = instance.send(:flatten_hadith_item, item)

      # Grades without graded_by should still be included
      expect(result).to include('en_body' => 'text')
      expect(result['grades']).to eq([{ 'grade' => 'Sahih', 'gradeBy' => nil }])
    end

    it 'handles nil graded_by in grades' do
      item = {
        'urn' => 305,
        'hadith' => [
          {
            'lang' => 'en',
            'body' => 'text',
            'grades' => [
              { 'graded_by' => nil, 'grade' => 'Sahih' },
              { 'graded_by' => 'Scholar', 'grade' => 'Hasan' }
            ]
          }
        ]
      }
      result = instance.send(:flatten_hadith_item, item)

      expect(result['grades']).to match_array([
        { 'grade' => 'Sahih', 'gradeBy' => nil },
        { 'grade' => 'Hasan', 'gradeBy' => 'Scholar' }
      ])
    end

    it 'handles nil grades array' do
      item = {
        'urn' => 305,
        'hadith' => [
          {
            'lang' => 'en',
            'body' => 'text',
            'grades' => nil # grades array is nil
          }
        ]
      }
      result = instance.send(:flatten_hadith_item, item)

      expect(result).to include('en_body' => 'text')
      expect(result).not_to have_key('grades') # No grades if all are nil
    end

    it 'deduplicates grade objects' do
      item = {
        'urn' => 305,
        'hadith' => [
          {
            'lang' => 'en',
            'body' => 'text',
            'grades' => [
              { 'graded_by' => 'Scholar', 'grade' => 'Sahih' },
              { 'graded_by' => 'Scholar', 'grade' => 'Sahih' }, # duplicate
              { 'graded_by' => 'Another', 'grade' => 'Sahih' }
            ]
          }
        ]
      }
      result = instance.send(:flatten_hadith_item, item)

      expect(result['grades']).to match_array([
        { 'grade' => 'Sahih', 'gradeBy' => 'Scholar' },
        { 'grade' => 'Sahih', 'gradeBy' => 'Another' }
      ]) # deduplicated
    end

    it 'adds collection name when collection exists' do
      bukhari_collection = {
        'name' => 'bukhari',
        'collection' => [
          { 'lang' => 'en', 'title' => 'Sahih al-Bukhari', 'shortIntro' => '...' },
          { 'lang' => 'ar', 'title' => 'صحيح البخاري', 'shortIntro' => '...' }
        ]
      }
      allow(instance).to receive(:get_collection).with('bukhari').and_return(bukhari_collection)

      item = {
        'collection' => 'bukhari',
        'urn' => 305,
        'hadith' => [
          { 'lang' => 'en', 'body' => 'text', 'urn' => 31, 'grades' => [] }
        ]
      }

      result = instance.send(:flatten_hadith_item, item, language: 'en')
      expect(result['name']).to eq('Sahih al-Bukhari')
      expect(result['collection']).to eq('bukhari')
    end

    it 'adds Arabic collection name when language is ar' do
      bukhari_collection = {
        'name' => 'bukhari',
        'collection' => [
          { 'lang' => 'en', 'title' => 'Sahih al-Bukhari', 'shortIntro' => '...' },
          { 'lang' => 'ar', 'title' => 'صحيح البخاري', 'shortIntro' => '...' }
        ]
      }
      allow(instance).to receive(:get_collection).with('bukhari').and_return(bukhari_collection)

      item = {
        'collection' => 'bukhari',
        'urn' => 305,
        'hadith' => [
          { 'lang' => 'ar', 'body' => 'text', 'urn' => 32, 'grades' => [] }
        ]
      }

      result = instance.send(:flatten_hadith_item, item, language: 'ar')
      expect(result['name']).to eq('صحيح البخاري')
      expect(result['collection']).to eq('bukhari')
    end

    it 'does not add collection name when collection is not found' do
      allow(instance).to receive(:get_collection).with('unknown').and_return(nil)

      item = {
        'collection' => 'unknown',
        'urn' => 305,
        'hadith' => [
          { 'lang' => 'en', 'body' => 'text', 'urn' => 31, 'grades' => [] }
        ]
      }

      result = instance.send(:flatten_hadith_item, item, language: 'en')
      expect(result).not_to have_key('name')
      expect(result['collection']).to eq('unknown')
    end

    it 'does not add collection name when collection is missing' do
      item = {
        'urn' => 305,
        'hadith' => [
          { 'lang' => 'en', 'body' => 'text', 'urn' => 31, 'grades' => [] }
        ]
      }

      result = instance.send(:flatten_hadith_item, item, language: 'en')
      expect(result).not_to have_key('name')
    end

    it 'does not add collection name when collection has no title for language' do
      collection_without_title = {
        'name' => 'bukhari',
        'collection' => [
          { 'lang' => 'fr', 'title' => 'Sahih al-Bukhari (French)' }
        ]
      }
      allow(instance).to receive(:get_collection).with('bukhari').and_return(collection_without_title)

      item = {
        'collection' => 'bukhari',
        'urn' => 305,
        'hadith' => [
          { 'lang' => 'en', 'body' => 'text', 'urn' => 31, 'grades' => [] }
        ]
      }

      result = instance.send(:flatten_hadith_item, item, language: 'en')
      expect(result).not_to have_key('name')
      expect(result['collection']).to eq('bukhari')
    end
  end

  describe '#get_collection' do
    let(:collections_response) do
      {
        'data' => [
          {
            'name' => 'bukhari',
            'hasBooks' => true,
            'hasChapters' => true,
            'collection' => [{ 'lang' => 'en', 'title' => 'Sahih al-Bukhari', 'shortIntro' => '...' }],
            'totalHadith' => 7563,
            'totalAvailableHadith' => 7563
          },
          {
            'name' => 'muslim',
            'hasBooks' => true,
            'hasChapters' => true,
            'collection' => [{ 'lang' => 'en', 'title' => 'Sahih Muslim', 'shortIntro' => '...' }],
            'totalHadith' => 7500,
            'totalAvailableHadith' => 7500
          }
        ],
        'total' => 2,
        'limit' => 100,
        'previous' => nil,
        'next' => nil
      }
    end

    it 'fetches all collections in one call and stores by name' do
      expect(Faraday).to receive(:get).with(
        'https://api.sunnah.com/v1/collections',
        { limit: 100, page: 1 },
        { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
      ).and_return(double(status: 200, body: Oj.dump(collections_response)))

      result = instance.get_collection('bukhari')
      expect(result).to include('name' => 'bukhari')

      all = instance.collections
      expect(all.map { |c| c['name'] }).to match_array(%w[bukhari muslim])
    end

    it 'uses the cache for subsequent calls' do
      allow(Faraday).to receive(:get).and_return(
        double(status: 200, body: Oj.dump(collections_response))
      )

      first = instance.get_collection('muslim')
      expect(first).to include('name' => 'muslim')

      expect(Faraday).not_to receive(:get)
      second = instance.get_collection('muslim')
      expect(second).to include('name' => 'muslim')
    end

    it 'returns nil for non-existent collection' do
      allow(Faraday).to receive(:get).and_return(
        double(status: 200, body: Oj.dump(collections_response))
      )

      result = instance.get_collection('nonexistent')
      expect(result).to be_nil
    end

    it 'returns nil for empty collection name' do
      expect(instance.get_collection('')).to be_nil
      expect(instance.get_collection('   ')).to be_nil
      expect(instance.get_collection(nil)).to be_nil
    end
  end

  describe 'environment variable requirements' do
    it 'raises ArgumentError when SUNNAH_API_KEY is not set' do
      ENV.delete('SUNNAH_API_KEY')

      expect {
        instance.hadith_by_urns_raw('305')
      }.to raise_error(ArgumentError, 'SUNNAH_API_KEY is required')
    end

    it 'raises ArgumentError when SUNNAH_API_URL is not set' do
      ENV.delete('SUNNAH_API_URL')

      expect {
        instance.hadith_by_urns_raw('305')
      }.to raise_error(ArgumentError, 'SUNNAH_API_URL is required')
    end

    it 'trims whitespace from environment variables' do
      ENV['SUNNAH_API_KEY'] = '  test-key  '
      ENV['SUNNAH_API_URL'] = '  https://api.example.com/  '

      expect(Faraday).to receive(:get).with(
        'https://api.example.com/hadiths/urns',
        { urns: '305' },
        { 'X-API-Key' => 'test-key', 'Accept' => 'application/json' }
      ).and_return(
        double(status: 200, body: Oj.dump({ 'count' => 0, 'missing' => [], 'data' => [] }))
      )

      instance.hadith_by_urns_raw('305')
    end

    it 'removes trailing slashes from URL' do
      ENV['SUNNAH_API_URL'] = 'https://api.example.com///'

      expect(Faraday).to receive(:get).with(
        'https://api.example.com/hadiths/urns',
        { urns: '305' },
        anything
      ).and_return(
        double(status: 200, body: Oj.dump({ 'count' => 0, 'missing' => [], 'data' => [] }))
      )

      instance.hadith_by_urns_raw('305')
    end
  end
end
