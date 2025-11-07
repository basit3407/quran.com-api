# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V4 Verses by range API', type: :request do
  describe 'GET /api/v4/verses/by_range' do
    let(:path) { '/api/v4/verses/by_range' }
    let(:from_key) { '1:1' }
    let(:to_key) { '1:3' }
    let(:verse_keys) { %w[1:1 1:2 1:3] }

    before do
      Verse.delete_all
      Chapter.delete_all
      Language.delete_all
      QiratType.delete_all
      Mushaf.delete_all
      VerseRoot.delete_all
      VerseLemma.delete_all
      VerseStem.delete_all

      Language.create!(iso_code: 'en', name: 'English', direction: 'ltr')

      qirat_type = QiratType.create!(name: 'Hafs')
      Mushaf.create!(
        name: 'Default Mushaf',
        enabled: true,
        is_default: true,
        lines_per_page: 15,
        pages_count: 604,
        qirat_type: qirat_type
      )

      chapter = Chapter.create!(
        chapter_number: 1,
        name_simple: 'Al-Fatihah',
        name_complex: 'Al-Fatihah',
        name_arabic: 'الفاتحة',
        revelation_place: 'makkah',
        revelation_order: 5,
        verses_count: 7,
        pages: '1-1',
        bismillah_pre: true,
        hizbs_count: 1,
        rub_el_hizbs_count: 1,
        rukus_count: 1
      )

      verse_root = VerseRoot.create!(value: 'root')
      verse_lemma = VerseLemma.create!(text_madani: 'lemma', text_clean: 'lemma')
      verse_stem = VerseStem.create!(text_madani: 'stem', text_clean: 'stem')

      verse_keys.each_with_index do |key, index|
        Verse.create!(
          chapter: chapter,
          verse_root: verse_root,
          verse_lemma: verse_lemma,
          verse_stem: verse_stem,
          verse_number: index + 1,
          verse_index: index + 1,
          verse_key: key,
          juz_number: 1,
          hizb_number: 1,
          rub_el_hizb_number: 1,
          manzil_number: 1,
          ruku_number: 1,
          page_number: 1
        )
      end
    end

    it 'returns verses within the requested range' do
      get path, params: { from: from_key, to: to_key }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['verses'].size).to eq(3)
      expect(json['verses'].map { |v| v['verse_key'] }).to eq(verse_keys)
    end

    it 'returns not found when params are missing' do
      get path, params: { from: from_key }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to include('From and to must be present')
    end

    it 'returns not found when range boundaries are invalid' do
      get path, params: { from: to_key, to: from_key }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to include('From should be smaller than to')
    end
  end
end
