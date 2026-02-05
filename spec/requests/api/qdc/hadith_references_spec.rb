# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::HadithReferences', type: :request do
  let(:language) { instance_double(Language, iso_code: 'en', direction: 'ltr') }

  before do
    allow(Language).to receive(:find_with_id_or_iso_code).and_return(language)
    allow(Language).to receive(:default).and_return(language)
  end

  def stub_ayah_id_lookup(mapping)
    allow(QuranUtils::Quran).to receive(:get_ayah_id_from_key) do |key|
      mapping[key]
    end
  end

  def stub_ayah_key_lookup(mapping)
    allow(QuranUtils::Quran).to receive(:get_ayah_key_from_id) do |id|
      mapping[id]
    end
  end

  def stub_count_query(result_hash)
    relation = instance_double(ActiveRecord::Relation)
    allow(Verse).to receive(:unscope).with(:order).and_return(relation)
    allow(relation).to receive(:where).with(verse_index: anything).and_return(relation)
    allow(relation).to receive(:joins).with(anything).and_return(relation)
    allow(relation).to receive(:group).with('verses.verse_key').and_return(relation)
    allow(relation).to receive(:pluck).with(anything).and_return(result_hash.to_a)
  end

  describe 'GET /api/qdc/hadith_references/by_ayah/:ayah_key' do
    let(:ayah_key) { '12:12' }
    let(:verse) do
      instance_double(Verse,
                      verse_key: ayah_key,
                      verse_number: 12,
                      chapter_id: 12,
                      verse_index: 12012)
    end

    let(:relation) { instance_double(ActiveRecord::Relation) }

    let(:reference_one) do
      instance_double(HadithReference,
                      id: 10,
                      collection: 'bukhari',
                      hadith_number: '1',
                      our_hadith_number: 1,
                      arabic_urn: 111,
                      english_urn: 211,
                      ayah_start_index: 12011,
                      ayah_end_index: 12012)
    end

    let(:reference_two) do
      instance_double(HadithReference,
                      id: 11,
                      collection: 'bukhari',
                      hadith_number: '2',
                      our_hadith_number: 2,
                      arabic_urn: 112,
                      english_urn: 212,
                      ayah_start_index: 12012,
                      ayah_end_index: 12012)
    end

    let(:reference_three) do
      instance_double(HadithReference,
                      id: 12,
                      collection: 'muslim',
                      hadith_number: '3',
                      our_hadith_number: 1,
                      arabic_urn: 113,
                      english_urn: 213,
                      ayah_start_index: 12012,
                      ayah_end_index: 12014)
    end

    it 'returns ordered references for the verse' do
      allow(Verse).to receive(:find_by).with(verse_key: ayah_key).and_return(verse)
      allow(HadithReference).to receive(:for_verse_index).with(verse.verse_index).and_return(relation)
      allow(relation).to receive(:order)
        .with(:collection, :our_hadith_number, :ayah_start_index, :ayah_end_index)
        .and_return(relation)
      allow(relation).to receive(:to_a).and_return([reference_one, reference_two, reference_three])

      stub_ayah_key_lookup(
        12011 => '12:11',
        12012 => '12:12',
        12014 => '12:14'
      )

      get "/api/qdc/hadith_references/by_ayah/#{ayah_key}", params: { language: 'en' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['verse_key']).to eq('12:12')
      expect(json['verse_number']).to eq(12)
      expect(json['chapter_number']).to eq(12)
      expect(json['language']).to eq('en')
      expect(json['direction']).to eq('ltr')

      expect(json['hadith_references'].map { |reference| reference['id'] }).to eq([10, 11, 12])

      first = json['hadith_references'].first
      expect(first['collection']).to eq('bukhari')
      expect(first['hadith_number']).to eq('1')
      expect(first['our_hadith_number']).to eq(1)
      expect(first['arabic_urn']).to eq(111)
      expect(first['english_urn']).to eq(211)
      expect(first['surah_number']).to eq(12)
      expect(first['ayah_start_number']).to eq(11)
      expect(first['ayah_end_number']).to eq(12)
    end

    it 'returns empty array when verse has no references' do
      allow(Verse).to receive(:find_by).with(verse_key: ayah_key).and_return(verse)
      allow(HadithReference).to receive(:for_verse_index).with(verse.verse_index).and_return(relation)
      allow(relation).to receive(:order)
        .with(:collection, :our_hadith_number, :ayah_start_index, :ayah_end_index)
        .and_return(relation)
      allow(relation).to receive(:to_a).and_return([])

      get "/api/qdc/hadith_references/by_ayah/#{ayah_key}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['verse_key']).to eq('12:12')
      expect(json['verse_number']).to eq(12)
      expect(json['chapter_number']).to eq(12)
      expect(json['hadith_references']).to eq([])
      expect(json['language']).to eq('en')
      expect(json['direction']).to eq('ltr')
    end

    it 'returns error for invalid ayah key format' do
      get '/api/qdc/hadith_references/by_ayah/12-12'

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('INVALID_PARAMETER')
      expect(json['error']['details']['parameter']).to eq('ayah_key')
    end

    it 'returns not found for missing verse' do
      allow(Verse).to receive(:find_by).with(verse_key: '999:999').and_return(nil)

      get '/api/qdc/hadith_references/by_ayah/999:999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('NOT_FOUND')
    end
  end

  describe 'GET /api/qdc/hadith_references/by_ayah/:ayah_key/hadiths' do
    let(:ayah_key) { '12:12' }
    let(:verse) do
      instance_double(Verse,
                      verse_key: ayah_key,
                      verse_index: 12012)
    end

    let(:relation) { instance_double(ActiveRecord::Relation) }
    let(:sunnah_api) { instance_double(SunnahApi) }

    let(:reference_one) do
      instance_double(HadithReference,
                      arabic_urn: 101,
                      english_urn: 201)
    end

    let(:reference_two) do
      instance_double(HadithReference,
                      arabic_urn: 102,
                      english_urn: 202)
    end

    let(:reference_three) do
      instance_double(HadithReference,
                      arabic_urn: 103,
                      english_urn: 203)
    end

    let(:reference_four) do
      instance_double(HadithReference,
                      arabic_urn: 104,
                      english_urn: 204)
    end

    let(:reference_five) do
      instance_double(HadithReference,
                      arabic_urn: 105,
                      english_urn: 205)
    end

    before do
      allow(Verse).to receive(:find_by).with(verse_key: ayah_key).and_return(verse)
      allow(HadithReference).to receive(:for_verse_index).with(verse.verse_index).and_return(relation)
      allow(relation).to receive(:order)
        .with(:collection, :our_hadith_number, :ayah_start_index, :ayah_end_index)
        .and_return(relation)
      allow(SunnahApi).to receive(:instance).and_return(sunnah_api)
    end

    it 'returns paginated hadiths using english URNs by default' do
      allow(relation).to receive(:limit).with(5).and_return(relation)
      allow(relation).to receive(:offset).with(0).and_return([
        reference_one, reference_two, reference_three, reference_four, reference_five
      ])

      expect(sunnah_api).to receive(:hadith_by_urns)
        .with([201, 202, 203, 204], language: 'en')
        .and_return('data' => [
          { 'urn' => 201 },
          { 'urn' => 202 },
          { 'urn' => 203 },
          { 'urn' => 204 }
        ])

      get "/api/qdc/hadith_references/by_ayah/#{ayah_key}/hadiths"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['hadiths'].size).to eq(4)
      expect(json['hadiths'].first['urn']).to eq(201)
      expect(json['page']).to eq(1)
      expect(json['limit']).to eq(4)
      expect(json['has_more']).to eq(true)
      expect(json['language']).to eq('en')
      expect(json['direction']).to eq('ltr')
    end

    it 'uses arabic URNs when language is ar and respects page/limit' do
      arabic_language = instance_double(Language, iso_code: 'ar', direction: 'rtl')
      allow(Language).to receive(:find_with_id_or_iso_code).with('ar').and_return(arabic_language)

      allow(relation).to receive(:limit).with(3).and_return(relation)
      allow(relation).to receive(:offset).with(2).and_return([
        reference_three, reference_four, reference_five
      ])

      expect(sunnah_api).to receive(:hadith_by_urns)
        .with([103, 104], language: 'ar')
        .and_return('data' => [
          { 'urn' => 103 },
          { 'urn' => 104 }
        ])

      get "/api/qdc/hadith_references/by_ayah/#{ayah_key}/hadiths", params: { page: 2, limit: 2, language: 'ar' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['hadiths'].size).to eq(2)
      expect(json['hadiths'].first['urn']).to eq(103)
      expect(json['page']).to eq(2)
      expect(json['limit']).to eq(2)
      expect(json['has_more']).to eq(true)
      expect(json['language']).to eq('ar')
      expect(json['direction']).to eq('rtl')
    end
  end

  describe 'GET /api/qdc/hadith_references/count_within_range' do
    context 'with valid parameters' do
      it 'returns counts for verses within range' do
        stub_ayah_id_lookup('12:12' => 12012, '12:13' => 12013)
        stub_count_query('12:12' => 2, '12:13' => 2)

        get '/api/qdc/hadith_references/count_within_range', params: { from: '12:12', to: '12:13' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json).to eq({ '12:12' => 2, '12:13' => 2 })
        expect(json.keys).to eq(['12:12', '12:13'])
      end

      it 'returns correct count for single verse range' do
        stub_ayah_id_lookup('12:12' => 12012)
        stub_count_query('12:12' => 2)

        get '/api/qdc/hadith_references/count_within_range', params: { from: '12:12', to: '12:12' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json).to eq({ '12:12' => 2 })
      end

      it 'returns empty hash for range with no references' do
        stub_ayah_id_lookup('1:1' => 1001)
        stub_count_query({})

        get '/api/qdc/hadith_references/count_within_range', params: { from: '1:1', to: '1:1' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json).to eq({})
      end

      it 'accepts whitespace and strips it' do
        stub_ayah_id_lookup('12:12' => 12012, '12:13' => 12013)
        stub_count_query('12:12' => 2, '12:13' => 2)

        get '/api/qdc/hadith_references/count_within_range', params: { from: ' 12:12 ', to: ' 12:13 ' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['12:12']).to eq(2)
      end
    end

    context 'with missing parameters' do
      it 'returns error when from parameter is missing' do
        get '/api/qdc/hadith_references/count_within_range', params: { to: '12:13' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['details']['required']).to include('from')
      end

      it 'returns error when to parameter is missing' do
        get '/api/qdc/hadith_references/count_within_range', params: { from: '12:12' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['details']['required']).to include('to')
      end

      it 'returns error when both parameters are missing' do
        get '/api/qdc/hadith_references/count_within_range'

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['details']['required']).to match_array(['from', 'to'])
      end
    end

    context 'with invalid verse key format' do
      it 'returns error when from has invalid format' do
        get '/api/qdc/hadith_references/count_within_range', params: { from: 'invalid', to: '12:13' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['details']['from']).to eq('invalid')
        expect(json['error']['details']['to']).to eq('12:13')
      end

      it 'returns error when to has invalid format' do
        get '/api/qdc/hadith_references/count_within_range', params: { from: '12:12', to: 'not-valid' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['details']['from']).to eq('12:12')
        expect(json['error']['details']['to']).to eq('not-valid')
      end

      it 'returns error for format without colon separator' do
        get '/api/qdc/hadith_references/count_within_range', params: { from: '1212', to: '1213' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
      end
    end

    context 'with invalid verse keys' do
      it 'returns error when from references non-existent verse' do
        stub_ayah_id_lookup('999:999' => nil, '12:13' => 12013)

        get '/api/qdc/hadith_references/count_within_range', params: { from: '999:999', to: '12:13' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid verse keys')
      end

      it 'returns error when to references non-existent verse' do
        stub_ayah_id_lookup('12:12' => 12012, '999:999' => nil)

        get '/api/qdc/hadith_references/count_within_range', params: { from: '12:12', to: '999:999' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid verse keys')
      end
    end

    context 'with invalid range' do
      it 'returns error when from verse comes after to verse' do
        stub_ayah_id_lookup('12:13' => 12013, '12:12' => 12012)

        get '/api/qdc/hadith_references/count_within_range', params: { from: '12:13', to: '12:12' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('INVALID_PARAMETER')
        expect(json['error']['message']).to include('Invalid range')
      end
    end
  end
end
