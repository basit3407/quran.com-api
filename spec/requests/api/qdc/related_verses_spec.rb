# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::RelatedVerses', type: :request do
  let!(:english) { Language.find_by(iso_code: 'en') || create(:language, :english) }
  let(:arabic) { create(:language, iso_code: 'ar') }

  let(:chapter) do
    ch = create(:chapter, name_simple: 'Al-Fatihah', name_arabic: 'الفاتحة')
    create(:translated_name, resource: ch, language: english, name: 'The Opening')
    ch
  end
  let(:verse) { create(:verse, chapter: chapter, verse_key: '1:1', verse_number: 1, verse_index: 1) }
  let(:related_verse_1) { create(:verse, chapter: chapter, verse_key: '1:5', verse_number: 5, verse_index: 5) }
  let(:related_verse_2) { create(:verse, chapter: chapter, verse_key: '1:7', verse_number: 7, verse_index: 7) }
  let(:relation_type) { create(:relation_type, name: 'similar_topic') }

  describe 'GET /api/qdc/related_verses/by_key/:verse_key' do
    context 'when verse exists' do
      before do
        create(:related_verse, :approved,
               verse: verse,
               related_verse: related_verse_1,
               relation_type: relation_type)
        create(:related_verse, :approved,
               verse: related_verse_2,
               related_verse: verse,
               relation_type: relation_type)
      end

      it 'returns related verses' do
        get "/api/qdc/related_verses/by_key/#{verse.verse_key}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['related_verses']).to be_an(Array)
        expect(json['related_verses'].length).to eq(2)
      end

      it 'returns related verses ordered by verse_index' do
        get "/api/qdc/related_verses/by_key/#{verse.verse_key}"

        json = JSON.parse(response.body)
        verse_keys = json['related_verses'].map { |rv| rv['verse_key'] }

        expect(verse_keys).to eq(['1:5', '1:7'])
      end

      it 'includes required fields in response' do
        get "/api/qdc/related_verses/by_key/#{verse.verse_key}"

        json = JSON.parse(response.body)
        related = json['related_verses'].first

        expect(related['id']).to be_present
        expect(related['verse_id']).to be_present
        expect(related['verse_key']).to be_present
        expect(related['relation']).to be_present
        expect(related['chapter_name']).to be_present
      end

      it 'returns titleized relation type name by default' do
        get "/api/qdc/related_verses/by_key/#{verse.verse_key}"

        json = JSON.parse(response.body)
        expect(json['related_verses'].first['relation']).to eq('Similar Topic')
      end

      context 'with language parameter' do
        before do
          create(:localized_content,
                 resource: relation_type,
                 language: arabic,
                 text: 'موضوع مشابه')
        end

        it 'returns localized relation name' do
          get "/api/qdc/related_verses/by_key/#{verse.verse_key}", params: { language: 'ar' }

          json = JSON.parse(response.body)
          expect(json['related_verses'].first['relation']).to eq('موضوع مشابه')
        end
      end

      context 'with unapproved relationships' do
        before do
          create(:related_verse,
                 approved: false,
                 verse: verse,
                 related_verse: create(:verse, verse_index: 100),
                 relation_type: relation_type)
        end

        it 'only returns approved relationships' do
          get "/api/qdc/related_verses/by_key/#{verse.verse_key}"

          json = JSON.parse(response.body)
          expect(json['related_verses'].length).to eq(2)
        end
      end
    end

    context 'when verse has no related verses' do
      it 'returns empty array' do
        get "/api/qdc/related_verses/by_key/#{verse.verse_key}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['related_verses']).to eq([])
      end
    end

    context 'when verse does not exist' do
      it 'returns 404 error' do
        get '/api/qdc/related_verses/by_key/999:999'

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end