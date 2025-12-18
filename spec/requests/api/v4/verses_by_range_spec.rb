# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V4 Verses by range API', type: :request do
  describe 'GET /api/v4/verses/by_range' do
    let(:path) { '/api/v4/verses/by_range' }
    let(:from_key) { '1:1' }
    let(:to_key) { '1:3' }
    let(:verse_keys) { %w[1:1 1:2 1:3] }

    def create_verse!(chapter:, verse_number:, verse_root:, verse_lemma:, verse_stem:, page_number: 1)
      verse_key = "#{chapter.chapter_number}:#{verse_number}"

      Verse.create!(
        chapter: chapter,
        verse_root: verse_root,
        verse_lemma: verse_lemma,
        verse_stem: verse_stem,
        verse_number: verse_number,
        verse_index: QuranUtils::Quran.get_ayah_id_from_key(verse_key),
        verse_key: verse_key,
        juz_number: 1,
        hizb_number: 1,
        rub_el_hizb_number: 1,
        manzil_number: 1,
        ruku_number: 1,
        page_number: page_number
      )
    end

    before do
      Verse.delete_all
      Chapter.delete_all
      Language.delete_all
      QiratType.delete_all
      Mushaf.delete_all
      VerseRoot.delete_all
      VerseLemma.delete_all
      VerseStem.delete_all
      Translation.delete_all
      Tafsir.delete_all
      Word.delete_all
      WordTranslation.delete_all
      AudioFile.delete_all
      Recitation.delete_all
      Reciter.delete_all
      RecitationStyle.delete_all
      ResourceContent.delete_all
      Author.delete_all
      DataSource.delete_all
      Topic.delete_all
      Token.delete_all
      CharType.delete_all

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

      chapter1 = Chapter.create!(
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

      chapter2 = Chapter.create!(
        chapter_number: 2,
        name_simple: 'Al-Baqarah',
        name_complex: 'Al-Baqarah',
        name_arabic: 'البقرة',
        revelation_place: 'madinah',
        revelation_order: 87,
        verses_count: 286,
        pages: '2-49',
        bismillah_pre: true,
        hizbs_count: 40,
        rub_el_hizbs_count: 40,
        rukus_count: 40
      )

      verse_root = VerseRoot.create!(value: 'root')
      verse_lemma = VerseLemma.create!(text_madani: 'lemma', text_clean: 'lemma')
      verse_stem = VerseStem.create!(text_madani: 'stem', text_clean: 'stem')

      (1..7).each do |verse_number|
        create_verse!(
          chapter: chapter1,
          verse_number: verse_number,
          verse_root: verse_root,
          verse_lemma: verse_lemma,
          verse_stem: verse_stem
        )
      end

      (1..3).each do |verse_number|
        create_verse!(
          chapter: chapter2,
          verse_number: verse_number,
          verse_root: verse_root,
          verse_lemma: verse_lemma,
          verse_stem: verse_stem,
          page_number: 2
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

    it 'returns a single verse when from equals to' do
      get path, params: { from: '1:2', to: '1:2' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['verses'].size).to eq(1)
      expect(json['verses'].first['verse_key']).to eq('1:2')
    end

    it 'returns verses across chapters within the requested range' do
      get path, params: { from: '1:7', to: '2:2' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['verses'].map { |v| v['verse_key'] }).to eq(%w[1:7 2:1 2:2])
    end

    it 'paginates the requested range using per_page and page params' do
      get path, params: { from: '1:1', to: '1:7', per_page: 2, page: 2 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['verses'].map { |v| v['verse_key'] }).to eq(%w[1:3 1:4])
      expect(json['pagination']).to include(
        'per_page' => 2,
        'current_page' => 2,
        'next_page' => 3,
        'total_pages' => 4,
        'total_records' => 7
      )
    end

    it 'renders words, translations, audio, and tafsirs when requested' do
      verse = Verse.find_by!(verse_key: '1:1')
      language = Language.find_by!(iso_code: 'en')

      author = Author.create!(name: 'Test Author')
      data_source = DataSource.create!(name: 'Test Source')

      word_translation_resource = ResourceContent.create!(
        approved: true,
        author: author,
        data_source: data_source,
        cardinality_type: ResourceContent::CardinalityType::OneWord,
        name: 'WBW Translation',
        sub_type: ResourceContent::SubType::Translation
      )

      translation_resource = ResourceContent.create!(
        approved: true,
        author: author,
        data_source: data_source,
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        name: 'Test Translation',
        sub_type: ResourceContent::SubType::Translation
      )

      tafsir_resource = ResourceContent.create!(
        approved: true,
        author: author,
        data_source: data_source,
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        name: 'Test Tafsir',
        sub_type: ResourceContent::SubType::Tafsir
      )

      audio_resource = ResourceContent.create!(
        approved: true,
        author: author,
        data_source: data_source,
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        name: 'Test Audio',
        sub_type: ResourceContent::SubType::Audio
      )

      char_type = CharType.create!(name: 'word')
      token = Token.create!(text: 'بسم')
      topic = Topic.create!(name: 'test topic')

      word = Word.create!(
        verse: verse,
        chapter_id: verse.chapter_id,
        position: 1,
        verse_key: verse.verse_key,
        page_number: 1,
        line_number: 1,
        code_v1: '01',
        char_type: char_type,
        char_type_name: 'word',
        token: token,
        topic: topic,
        en_transliteration: 'bismi',
        text_uthmani: 'بِسْمِ'
      )

      WordTranslation.create!(
        word: word,
        language: language,
        resource_content: word_translation_resource,
        text: 'in the name',
        language_name: 'English'
      )

      Translation.create!(
        verse: verse,
        language: language,
        resource_content: translation_resource,
        text: 'In the name of Allah',
        verse_key: verse.verse_key,
        verse_number: verse.verse_number,
        chapter_id: verse.chapter_id,
        language_name: 'English'
      )

      Tafsir.create!(
        verse: verse,
        language: language,
        resource_content: tafsir_resource,
        text: 'A brief tafsir',
        verse_key: verse.verse_key,
        verse_number: verse.verse_number,
        chapter_id: verse.chapter_id,
        language_name: 'English'
      )

      reciter = Reciter.create!(name: 'Test Reciter')
      style = RecitationStyle.create!(name: 'Test Style')

      recitation = Recitation.create!(
        reciter: reciter,
        recitation_style: style,
        resource_content: audio_resource
      )

      AudioFile.create!(
        verse: verse,
        recitation: recitation,
        url: 'https://example.com/1_1.mp3',
        segments: [[0, 0, 1000]]
      )

      get path, params: {
        from: '1:1',
        to: '1:1',
        words: true,
        translations: translation_resource.id.to_s,
        tafsirs: tafsir_resource.id.to_s,
        audio: recitation.id.to_s
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      verse_json = json['verses'].first

      expect(verse_json['words']).to be_present
      expect(verse_json['translations']).to be_present
      expect(verse_json['tafsirs']).to be_present
      expect(verse_json['audio']).to include('url' => 'https://example.com/1_1.mp3')

      expect(verse_json.dig('translations', 0, 'text')).to eq('In the name of Allah')
      expect(verse_json.dig('tafsirs', 0, 'text')).to eq('A brief tafsir')
      expect(verse_json.dig('words', 0, 'translation', 'text')).to eq('in the name')
    end
  end
end
