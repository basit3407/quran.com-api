# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Qdc::Verses', type: :request do

  let!(:english) { Language.find_by(iso_code: 'en') || create(:language, :english) }
  let!(:default_mushaf) { create(:mushaf, is_default: true, enabled: true) }

  let(:chapter) do
    ch = create(:chapter, name_simple: 'Al-Fatihah', name_arabic: 'الفاتحة')
    create(:translated_name, resource: ch, language: english, name: 'The Opening')
    ch
  end

  describe 'GET /api/qdc/verses/by_key/:verse_key' do
    let(:verse) { create(:verse, chapter: chapter, verse_key: '1:1', verse_number: 1, verse_index: 1) }

    context 'when related_verses param is true' do
      let(:related_verse) { create(:verse, chapter: chapter, verse_key: '1:5', verse_number: 5, verse_index: 5) }
      let(:relation_type) { create(:relation_type, name: 'similar_topic') }

      before do
        create(:related_verse, :approved,
               verse: verse,
               related_verse: related_verse,
               relation_type: relation_type)
      end

      it 'returns related verses' do
        get "/api/qdc/verses/by_key/#{verse.verse_key}", params: { related_verses: true }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['verse']['related_verses']).to be_an(Array)
        expect(json['verse']['related_verses'].length).to eq(1)
        expect(json['verse']['related_verses'][0]['verse_key']).to eq(related_verse.verse_key)
        expect(json['verse']['has_related_verses']).to be true
      end
    end

    context 'when related_verses param is false' do
      let(:related_verse) { create(:verse, chapter: chapter, verse_key: '1:5', verse_number: 5, verse_index: 5) }
      let(:relation_type) { create(:relation_type, name: 'similar_topic') }

      before do
        create(:related_verse, :approved,
               verse: verse,
               related_verse: related_verse,
               relation_type: relation_type)
      end

      it 'does not return related verses' do
        get "/api/qdc/verses/by_key/#{verse.verse_key}", params: { related_verses: false }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['verse']['related_verses']).to be_nil
        expect(json['verse']['has_related_verses']).to be true
      end
    end

    context 'when related_verses param is missing' do
      let(:related_verse) { create(:verse, chapter: chapter, verse_key: '1:5', verse_number: 5, verse_index: 5) }
      let(:relation_type) { create(:relation_type, name: 'similar_topic') }

      before do
        create(:related_verse, :approved,
               verse: verse,
               related_verse: related_verse,
               relation_type: relation_type)
      end

      it 'does not return related verses' do
        get "/api/qdc/verses/by_key/#{verse.verse_key}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['verse']['related_verses']).to be_nil
        expect(json['verse']['has_related_verses']).to be true
      end
    end

    context 'when verse has no related verses' do
      it 'returns has_related_verses as false' do
        get "/api/qdc/verses/by_key/#{verse.verse_key}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['verse']['related_verses']).to be_nil
        expect(json['verse']['has_related_verses']).to be false
      end
    end
  end
end