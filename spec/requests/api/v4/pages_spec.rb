# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::V4 Pages', type: :request do
  before do
    [
      MushafPage,
      MushafJuz,
      Juz,
      Verse,
      Chapter,
      Mushaf,
      QiratType,
      VerseRoot,
      VerseLemma,
      VerseStem
    ].each(&:delete_all)

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
    @indopak_mushaf = Mushaf.create!(
      id: 6,
      name: 'Indopak Mushaf',
      enabled: true,
      is_default: false,
      lines_per_page: 16,
      pages_count: 610,
      qirat_type: @qirat_type
    )

    @chapter = Chapter.create!(
      chapter_number: 2,
      name_simple: 'Test Chapter',
      name_complex: 'Test Chapter',
      name_arabic: 'Test Chapter',
      revelation_place: 'madinah',
      revelation_order: 87,
      verses_count: 5,
      pages: '2-3',
      bismillah_pre: true,
      hizbs_count: 1,
      rub_el_hizbs_count: 1,
      rukus_count: 1
    )

    @verse_root = VerseRoot.create!(value: 'root')
    @verse_lemma = VerseLemma.create!(text_madani: 'lemma', text_clean: 'lemma')
    @verse_stem = VerseStem.create!(text_madani: 'stem', text_clean: 'stem')

    @verses = (1..5).map do |verse_number|
      create_verse(
        chapter: @chapter,
        verse_number: verse_number,
        page_mapping: default_page_mapping_for(verse_number),
        juz_mapping: { 'madani' => 1, 'indopak' => 1 }
      )
    end

    @juz = Juz.create!(
      juz_number: 1,
      first_verse_id: @verses.first.id,
      last_verse_id: @verses.last.id,
      verses_count: @verses.size,
      verse_mapping: {}
    )

    MushafJuz.create!(
      mushaf: @default_mushaf,
      juz: @juz,
      first_verse: @verses.first,
      last_verse: @verses.last,
      mushaf_type: :madani,
      juz_number: 1,
      verses_count: @verses.size,
      verse_mapping: {}
    )
    MushafJuz.create!(
      mushaf: @indopak_mushaf,
      juz: @juz,
      first_verse: @verses.first,
      last_verse: @verses[3],
      mushaf_type: :indopak,
      juz_number: 1,
      verses_count: 4,
      verse_mapping: {}
    )

    create_page(@default_mushaf, 2, @verses.first, @verses[1], { '2:1' => '2:2' })
    create_page(@default_mushaf, 3, @verses[2], @verses.last, { '2:3' => '2:5' })
    create_page(@indopak_mushaf, 10, @verses.first, @verses[2], { '2:1' => '2:3' })
    create_page(@indopak_mushaf, 11, @verses[3], @verses.last, { '2:4' => '2:5' })
  end

  describe 'GET /api/v4/pages' do
    it 'returns pages for the selected mushaf' do
      get '/api/v4/pages', params: { mushaf: @indopak_mushaf.id }

      expect(response).to have_http_status(:ok)
      expect(response_json['pages'].map { |page| page['page_number'] }).to eq([10, 11])
      expect(response_json['pages'].first).to include(
        'page_number' => 10,
        'first_verse_id' => @verses.first.id,
        'last_verse_id' => @verses[2].id,
        'verses_count' => 3
      )
    end
  end

  describe 'GET /api/v4/pages/:id' do
    it 'returns page metadata for the selected mushaf page number' do
      get '/api/v4/pages/10', params: { mushaf: @indopak_mushaf.id }

      expect(response).to have_http_status(:ok)
      expect(response_json['page']).to include(
        'page_number' => 10,
        'first_verse_id' => @verses.first.id,
        'last_verse_id' => @verses[2].id,
        'verses_count' => 3
      )
    end
  end

  describe 'GET /api/v4/pages/lookup' do
    it 'looks up pages for a chapter in the selected mushaf' do
      get '/api/v4/pages/lookup', params: { chapter_number: @chapter.chapter_number, mushaf: @indopak_mushaf.id }

      expect(response).to have_http_status(:ok)
      expect(response_json['total_page']).to eq(2)
      expect(response_json['lookup_range']).to eq({ 'from' => '2:1', 'to' => '2:5' })
      expect(response_json['pages'].keys).to eq(%w[10 11])
      expect(response_json['pages']['10']).to include(
        'first_verse_key' => '2:1',
        'last_verse_key' => '2:3',
        'from' => '2:1',
        'to' => '2:3'
      )
    end

    it 'looks up pages for juzs using mushaf-specific juz ranges' do
      get '/api/v4/pages/lookup', params: { juz_number: 1, mushaf: @indopak_mushaf.id }

      expect(response).to have_http_status(:ok)
      expect(response_json['lookup_range']).to eq({ 'from' => '2:1', 'to' => '2:4' })
      expect(response_json['pages'].keys).to eq(%w[10 11])
      expect(response_json['pages']['11']['to']).to eq('2:4')
    end

    it 'looks up a single page number in the selected mushaf' do
      get '/api/v4/pages/lookup', params: { page_number: 10, mushaf: @indopak_mushaf.id }

      expect(response).to have_http_status(:ok)
      expect(response_json['total_page']).to eq(1)
      expect(response_json['lookup_range']).to eq({ 'from' => '2:1', 'to' => '2:3' })
      expect(response_json['pages']).to eq(
        '10' => {
          'first_verse_key' => '2:1',
          'last_verse_key' => '2:3',
          'from' => '2:1',
          'to' => '2:3'
        }
      )
    end

    it 'looks up arbitrary verse ranges and clips page-local ranges correctly' do
      get '/api/v4/pages/lookup', params: { from: '2:2', to: '2:4', mushaf: @indopak_mushaf.id }

      expect(response).to have_http_status(:ok)
      expect(response_json['lookup_range']).to eq({ 'from' => '2:2', 'to' => '2:4' })
      expect(response_json['pages']).to eq(
        '10' => {
          'first_verse_key' => '2:1',
          'last_verse_key' => '2:3',
          'from' => '2:2',
          'to' => '2:3'
        },
        '11' => {
          'first_verse_key' => '2:4',
          'last_verse_key' => '2:5',
          'from' => '2:4',
          'to' => '2:4'
        }
      )
    end
  end

  def create_verse(chapter:, verse_number:, page_mapping:, juz_mapping:)
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
      page_number: page_mapping.fetch('1'),
      v2_page: page_mapping.fetch('1'),
      mushaf_pages_mapping: page_mapping,
      mushaf_juzs_mapping: juz_mapping
    )
  end

  def default_page_mapping_for(verse_number)
    {
      '1' => verse_number <= 2 ? 2 : 3,
      '6' => verse_number <= 3 ? 10 : 11
    }
  end

  def create_page(mushaf, page_number, first_verse, last_verse, verse_mapping)
    MushafPage.create!(
      mushaf: mushaf,
      page_number: page_number,
      verse_mapping: verse_mapping,
      verses_count: (last_verse.verse_number - first_verse.verse_number) + 1,
      first_verse_id: first_verse.id,
      last_verse_id: last_verse.id
    )
  end
end
