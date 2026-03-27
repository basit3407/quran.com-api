# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::V4 Verses by page', type: :request do
  before do
    [
      MushafWord,
      MushafPage,
      WordTranslation,
      Word,
      Verse,
      Chapter,
      Mushaf,
      QiratType,
      Language,
      ResourceContent,
      Author,
      DataSource,
      CharType,
      Token,
      Topic,
      VerseRoot,
      VerseLemma,
      VerseStem
    ].each(&:delete_all)

    @language = Language.create!(iso_code: 'en', name: 'English', direction: 'ltr')
    @author = Author.create!(name: 'Spec Author')
    @data_source = DataSource.create!(name: 'Spec Source')
    @word_translation_resource = ResourceContent.create!(
      approved: true,
      permission_to_share: :granted,
      author: @author,
      data_source: @data_source,
      cardinality_type: ResourceContent::CardinalityType::OneWord,
      sub_type: ResourceContent::SubType::Translation,
      resource_type: ResourceContent::ResourceType::Content,
      language_id: @language.id,
      language_name: @language.name,
      name: 'WBW'
    )

    @qirat_type = QiratType.create!(name: 'Hafs')
    @default_mushaf = Mushaf.create!(
      id: 1,
      name: 'Default Mushaf',
      enabled: true,
      is_default: true,
      lines_per_page: 15,
      pages_count: 604,
      qirat_type: @qirat_type
    )
    @king_fahd_mushaf = Mushaf.create!(
      id: 5,
      name: 'King Fahd 1441',
      enabled: true,
      is_default: false,
      lines_per_page: 15,
      pages_count: 604,
      qirat_type: @qirat_type
    )

    @chapter_47 = Chapter.create!(
      chapter_number: 47,
      name_simple: 'Muhammad',
      name_complex: 'Muhammad',
      name_arabic: 'Muhammad',
      revelation_place: 'madinah',
      revelation_order: 95,
      verses_count: 3,
      pages: '507-508',
      bismillah_pre: true,
      hizbs_count: 1,
      rub_el_hizbs_count: 1,
      rukus_count: 1
    )
    @chapter_48 = Chapter.create!(
      chapter_number: 48,
      name_simple: 'Fath',
      name_complex: 'Fath',
      name_arabic: 'Fath',
      revelation_place: 'madinah',
      revelation_order: 111,
      verses_count: 1,
      pages: '511-511',
      bismillah_pre: true,
      hizbs_count: 1,
      rub_el_hizbs_count: 1,
      rukus_count: 1
    )

    @verse_root = VerseRoot.create!(value: 'root')
    @verse_lemma = VerseLemma.create!(text_madani: 'lemma', text_clean: 'lemma')
    @verse_stem = VerseStem.create!(text_madani: 'stem', text_clean: 'stem')

    @verse_47_1 = create_verse(@chapter_47, 1, default_page: 507, king_fahd_page: 507)
    @verse_47_2 = create_verse(@chapter_47, 2, default_page: 507, king_fahd_page: 507)
    @verse_47_3 = create_verse(@chapter_47, 3, default_page: 508, king_fahd_page: 507)
    @verse_48_1 = create_verse(@chapter_48, 1, default_page: 511, king_fahd_page: 511)

    create_page(@default_mushaf, 507, @verse_47_1, @verse_47_2)
    create_page(@default_mushaf, 508, @verse_47_3, @verse_47_3)
    create_page(@default_mushaf, 511, @verse_48_1, @verse_48_1)

    create_page(@king_fahd_mushaf, 507, @verse_47_1, @verse_47_3)
    create_page(@king_fahd_mushaf, 511, @verse_48_1, @verse_48_1)

    @char_type = CharType.create!(name: 'word')
    @token = Token.create!(text: 'token')
    @topic = Topic.create!(name: 'topic')

    verse_47_1_words = create_words_for_verse(@verse_47_1, [
      { position: 2, text_qpc_hafs: 'GEN-LAST' },
      { position: 1, text_qpc_hafs: 'GEN-FIRST' }
    ])
    verse_47_2_words = create_words_for_verse(@verse_47_2, [
      { position: 1, text_qpc_hafs: 'GEN-V2-1' }
    ])
    verse_47_3_words = create_words_for_verse(@verse_47_3, [
      { position: 1, text_qpc_hafs: 'GEN-V3-1' }
    ])
    verse_48_1_words = create_words_for_verse(@verse_48_1, [
      { position: 1, text_qpc_hafs: 'GEN-V48-1' }
    ])

    create_mushaf_words(@default_mushaf, @verse_47_1, verse_47_1_words, page_number: 507, line_numbers: [2, 2], texts: ['DEF-FIRST', 'DEF-SECOND'], positions: [1, 2])
    create_mushaf_words(@default_mushaf, @verse_47_2, verse_47_2_words, page_number: 507, line_numbers: [3], texts: ['DEF-V2-1'], positions: [1])
    create_mushaf_words(@default_mushaf, @verse_47_3, verse_47_3_words, page_number: 508, line_numbers: [2], texts: ['DEF-V3-1'], positions: [1])
    create_mushaf_words(@default_mushaf, @verse_48_1, verse_48_1_words, page_number: 511, line_numbers: [3], texts: ['DEF-V48-1'], positions: [1])

    create_mushaf_words(@king_fahd_mushaf, @verse_47_1, verse_47_1_words, page_number: 507, line_numbers: [2, 2], texts: ['KF-FIRST', 'KF-SECOND'], positions: [1, 2])
    create_mushaf_words(@king_fahd_mushaf, @verse_47_2, verse_47_2_words, page_number: 507, line_numbers: [3], texts: ['KF-V2-1'], positions: [1])
    create_mushaf_words(@king_fahd_mushaf, @verse_47_3, verse_47_3_words, page_number: 507, line_numbers: [4], texts: ['KF-V3-1'], positions: [1])
    create_mushaf_words(@king_fahd_mushaf, @verse_48_1, verse_48_1_words, page_number: 511, line_numbers: [3], texts: ['KF-V48-1'], positions: [1])
  end

  describe 'GET /api/v4/verses/by_page/:page_number' do
    it 'uses the selected mushaf page range and mushaf words for page layout' do
      get '/api/v4/verses/by_page/507', params: {
        mushaf: @king_fahd_mushaf.id,
        words: true,
        word_fields: 'text_qpc_hafs,line_number,page_number'
      }

      expect(response).to have_http_status(:ok)
      expect(response_json['verses'].map { |verse| verse['verse_key'] }).to eq(%w[47:1 47:2 47:3])

      first_verse = response_json['verses'].first
      expect(first_verse['page_number']).to eq(507)
      expect(first_verse['words'].map { |word| word['text'] }).to eq(%w[KF-FIRST KF-SECOND])
      expect(first_verse['words'].map { |word| word['page_number'] }.uniq).to eq([507])
      expect(first_verse['words'].map { |word| word['line_number'] }.uniq).to eq([2])
      expect(first_verse['words'].map { |word| word['text_qpc_hafs'] }).to eq(%w[GEN-LAST GEN-FIRST])
    end

    it 'changes the selected page verses when mushaf changes' do
      get '/api/v4/verses/by_page/507', params: {
        words: true,
        word_fields: 'text_qpc_hafs,line_number,page_number'
      }

      expect(response).to have_http_status(:ok)
      expect(response_json['verses'].map { |verse| verse['verse_key'] }).to eq(%w[47:1 47:2])
      expect(response_json['verses'].first['words'].map { |word| word['text'] }).to eq(%w[DEF-FIRST DEF-SECOND])
    end

    it 'can legitimately start different pages on different physical line numbers' do
      get '/api/v4/verses/by_page/507', params: {
        mushaf: @king_fahd_mushaf.id,
        words: true,
        word_fields: 'line_number'
      }
      page_507_first_line = response_json['verses'].first['words'].first['line_number']

      get '/api/v4/verses/by_page/511', params: {
        mushaf: @king_fahd_mushaf.id,
        words: true,
        word_fields: 'line_number'
      }
      page_511_first_line = response_json['verses'].first['words'].first['line_number']

      expect(page_507_first_line).to eq(2)
      expect(page_511_first_line).to eq(3)
    end

    it 'keeps non-page verse endpoints on the existing generic word path' do
      get "/api/v4/verses/by_chapter/#{@chapter_47.chapter_number}", params: {
        words: true,
        word_fields: 'text_qpc_hafs,line_number,page_number'
      }

      expect(response).to have_http_status(:ok)
      first_verse = response_json['verses'].first
      expect(first_verse['page_number']).to eq(507)
      expect(first_verse['words'].map { |word| word['text'] }).to eq(%w[GEN-FIRST GEN-LAST])
      expect(first_verse['words'].map { |word| word['line_number'] }.uniq).to eq([99])
      expect(first_verse['words'].map { |word| word['page_number'] }.uniq).to eq([999])
    end
  end

  def create_verse(chapter, verse_number, default_page:, king_fahd_page:)
    verse_key = "#{chapter.chapter_number}:#{verse_number}"

    Verse.create!(
      chapter: chapter,
      verse_root: @verse_root,
      verse_lemma: @verse_lemma,
      verse_stem: @verse_stem,
      verse_number: verse_number,
      verse_index: QuranUtils::Quran.get_ayah_id_from_key(verse_key),
      verse_key: verse_key,
      juz_number: 1,
      hizb_number: 1,
      rub_el_hizb_number: 1,
      manzil_number: 1,
      ruku_number: 1,
      page_number: default_page,
      v2_page: default_page,
      mushaf_pages_mapping: {
        @default_mushaf.id.to_s => default_page,
        @king_fahd_mushaf.id.to_s => king_fahd_page
      },
      mushaf_juzs_mapping: {
        'madani' => 1
      }
    )
  end

  def create_page(mushaf, page_number, first_verse, last_verse)
    MushafPage.create!(
      mushaf: mushaf,
      page_number: page_number,
      verse_mapping: {},
      verses_count: (last_verse.id - first_verse.id) + 1,
      first_verse_id: first_verse.id,
      last_verse_id: last_verse.id
    )
  end

  def create_words_for_verse(verse, definitions)
    definitions.map do |definition|
      word = Word.create!(
        verse: verse,
        chapter_id: verse.chapter_id,
        position: definition.fetch(:position),
        verse_key: verse.verse_key,
        page_number: 999,
        line_number: 99,
        v2_page: 999,
        code_v1: 'W',
        code_v2: 'W2',
        text_qpc_hafs: definition.fetch(:text_qpc_hafs),
        text_uthmani: definition.fetch(:text_qpc_hafs),
        char_type: @char_type,
        char_type_name: 'word',
        token: @token,
        topic: @topic
      )

      WordTranslation.create!(
        word: word,
        language: @language,
        resource_content: @word_translation_resource,
        text: "translation-#{word.position}",
        language_name: @language.name
      )

      word
    end
  end

  def create_mushaf_words(mushaf, verse, words, page_number:, line_numbers:, texts:, positions:)
    words.zip(line_numbers, texts, positions).each_with_index do |(word, line_number, text, position_in_verse), index|
      MushafWord.create!(
        mushaf: mushaf,
        verse_id: verse.id,
        word: word,
        word_id: word.id,
        page_number: page_number,
        line_number: line_number,
        position_in_verse: position_in_verse,
        position_in_page: index + 1,
        position_in_line: index + 1,
        text: text,
        char_type_name: 'word',
        char_type_id: @char_type.id
      )
    end
  end
end
