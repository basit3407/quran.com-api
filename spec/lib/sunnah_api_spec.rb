# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SunnahApi do
  let(:instance) { described_class.instance }

  before do
    # Set required environment variables
    ENV['SUNNAH_API_KEY'] = 'test-api-key'
    ENV['SUNNAH_API_URL'] = 'https://api.sunnah.com'
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
          'https://api.sunnah.com/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw('305,306')
      end

      it 'accepts URNs as array of strings' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw(['305', '306'])
      end

      it 'accepts URNs as array of integers' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw([305, 306])
      end

      it 'accepts single URN as string' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/hadiths/urns',
          { urns: '305' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump({ 'count' => 1, 'missing' => [], 'data' => [] }))
        )

        instance.hadith_by_urns_raw('305')
      end

      it 'normalizes and trims whitespace from URNs' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/hadiths/urns',
          { urns: '305,306' },
          { 'X-API-Key' => 'test-api-key', 'Accept' => 'application/json' }
        ).and_return(
          double(status: 200, body: Oj.dump(success_response))
        )

        instance.hadith_by_urns_raw([' 305 ', ' 306 '])
      end

      it 'filters out empty values' do
        expect(Faraday).to receive(:get).with(
          'https://api.sunnah.com/hadiths/urns',
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
                  { 'lang' => 'en', 'graded_by' => 'Ahmad Muhammad Shakir', 'grade' => 'Sahih' },
                  { 'lang' => 'en', 'graded_by' => 'Another Scholar', 'grade' => 'Hasan' }
                ]
              },
              {
                'lang' => 'ar',
                'chapterNumber' => '1',
                'chapterTitle' => 'الوحي',
                'body' => 'حدثنا عمر بن الخطاب بالعربية...',
                'urn' => 32,
                'grades' => [
                  { 'lang' => 'ar', 'graded_by' => 'العلماء', 'grade' => 'صحيح' }
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
        expect(result['data'].first).to include('ar_body' => 'حدثنا عمر بن الخطاب بالعربية...')
        expect(result['data'].first).to include('ar_urn' => 32)

        # Should NOT have chapterNumber or chapterTitle
        expect(result['data'].first).not_to have_key('en_chapterNumber')
        expect(result['data'].first).not_to have_key('en_chapterTitle')
        expect(result['data'].first).not_to have_key('ar_chapterNumber')
        expect(result['data'].first).not_to have_key('ar_chapterTitle')

        # Should have combined grades from all hadith objects (as array of objects)
        expect(result['data'].first['grades']).to match_array([
          { 'grade' => 'Sahih', 'gradeBy' => 'Ahmad Muhammad Shakir' },
          { 'grade' => 'Hasan', 'gradeBy' => 'Another Scholar' },
          { 'grade' => 'صحيح', 'gradeBy' => 'العلماء' }
        ])

        # Hadith array should be removed, grades array should be present
        expect(result['data'].first).not_to have_key('hadith')
        expect(result['data'].first).to have_key('grades')
      end

      it 'preserves other non-hadith fields' do
        result = instance.hadith_by_urns('305')

        expect(result['data'].first['collection']).to eq('bukhari')
        expect(result['data'].first['bookNumber']).to eq('1')
        expect(result['data'].first['chapterId']).to eq('1')
        expect(result['data'].first['hadithNumber']).to eq('1')
      end
    end

    context 'with language: :ar' do
      before do
        allow(Faraday).to receive(:get).and_return(
          double(status: 200, body: Oj.dump(multi_language_response))
        )
      end

      it 'flattens only Arabic language data with combined Arabic grades' do
        result = instance.hadith_by_urns('305', language: :ar)

        # Should have only Arabic body and urn
        expect(result['data'].first).to include('ar_body' => 'حدثنا عمر بن الخطاب بالعربية...')
        expect(result['data'].first).to include('ar_urn' => 32)

        # Should have only Arabic grades (as array of objects)
        expect(result['data'].first['grades']).to eq([
          { 'grade' => 'صحيح', 'gradeBy' => 'العلماء' }
        ])

        # Should not have English prefixes
        expect(result['data'].first).not_to have_key('en_body')
        expect(result['data'].first).not_to have_key('en_urn')
      end

      it 'handles string language parameter' do
        result = instance.hadith_by_urns('305', language: 'ar')

        expect(result['data'].first).to include('ar_body')
        expect(result['data'].first).not_to have_key('en_body')
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
              { 'lang' => 'en', 'graded_by' => 'Scholar 1', 'grade' => 'Sahih' },
              { 'lang' => 'en', 'graded_by' => 'Scholar 2', 'grade' => 'Hasan' }
            ]
          },
          {
            'lang' => 'ar',
            'chapterNumber' => '1',
            'chapterTitle' => 'الوحي',
            'body' => 'Arabic text',
            'urn' => 32,
            'grades' => [
              { 'lang' => 'ar', 'graded_by' => 'عالم', 'grade' => 'صحيح' }
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

      # Should have combined grades from all hadith objects (as array of objects)
      expect(result['grades']).to match_array([
        { 'grade' => 'Sahih', 'gradeBy' => 'Scholar 1' },
        { 'grade' => 'Hasan', 'gradeBy' => 'Scholar 2' },
        { 'grade' => 'صحيح', 'gradeBy' => 'عالم' }
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

    it 'filters by only_language when provided' do
      result = instance.send(:flatten_hadith_item, item_with_hadith, only_language: 'en')

      expect(result).to have_key('en_body')
      expect(result).to have_key('en_urn')
      expect(result).to have_key('grades') # Combined grades without language prefix
      expect(result['grades']).to match_array([
        { 'grade' => 'Sahih', 'gradeBy' => 'Scholar 1' },
        { 'grade' => 'Hasan', 'gradeBy' => 'Scholar 2' }
      ]) # Only English grades
      expect(result).not_to have_key('ar_body')
      expect(result).not_to have_key('ar_urn')
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

    it 'handles grades without lang field gracefully' do
      item = {
        'urn' => 305,
        'hadith' => [
          {
            'lang' => 'en',
            'body' => 'text',
            'grades' => [
              { 'graded_by' => 'Scholar', 'grade' => 'Sahih' } # no lang field
            ]
          }
        ]
      }
      result = instance.send(:flatten_hadith_item, item)

      # Grades without lang should still be included
      expect(result).to include('en_body' => 'text')
      expect(result['grades']).to eq([{ 'grade' => 'Sahih', 'gradeBy' => 'Scholar' }])
    end

    it 'handles nil graded_by in grades' do
      item = {
        'urn' => 305,
        'hadith' => [
          {
            'lang' => 'en',
            'body' => 'text',
            'grades' => [
              { 'lang' => 'en', 'graded_by' => nil, 'grade' => 'Sahih' },
              { 'lang' => 'en', 'graded_by' => 'Scholar', 'grade' => 'Hasan' }
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
              { 'lang' => 'en', 'graded_by' => 'Scholar', 'grade' => 'Sahih' },
              { 'lang' => 'en', 'graded_by' => 'Scholar', 'grade' => 'Sahih' }, # duplicate
              { 'lang' => 'en', 'graded_by' => 'Another', 'grade' => 'Sahih' }
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
