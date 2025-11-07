# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::V4 Verses tafsir filters', type: :request do
  let(:endpoint) { '/api/v4/verses/by_chapter/spec-chapter-tafsir' }

  let!(:language) do
    Language.find_or_create_by!(iso_code: 'en') do |lang|
      lang.name = 'English'
    end
  end
  let!(:author) { Author.create!(name: 'Spec Author') }
  let!(:data_source) { DataSource.create!(name: 'Spec Source') }
  let!(:qirat_type) { QiratType.create!(name: 'Spec Qirat') }
  let!(:mushaf) do
    Mushaf.find_or_create_by!(is_default: true) do |record|
      record.name = 'Spec Mushaf'
      record.enabled = true
      record.qirat_type = qirat_type
      record.lines_per_page = 15
      record.pages_count = 604
    end
  end

  let!(:chapter) do
    Chapter.create!(
      chapter_number: 999,
      name_simple: 'Spec Chapter',
      name_complex: 'Spec Chapter',
      name_arabic: 'سورة خاصة',
      revelation_place: 'makkah',
      revelation_order: 5,
      hizbs_count: 1,
      rub_el_hizbs_count: 1,
      rukus_count: 1,
      verses_count: 2,
      pages: '1-1',
      bismillah_pre: true
    )
  end
  let!(:slug) { Slug.create!(chapter: chapter, slug: 'spec-chapter-tafsir') }

  let!(:verse_root) { VerseRoot.create!(value: 'root') }
  let!(:verse_lemma) { VerseLemma.create!(text_madani: 'lemma', text_clean: 'lemma') }
  let!(:verse_stem) { VerseStem.create!(text_madani: 'stem', text_clean: 'stem') }

  let!(:verse_one) { create_verse(1, 7001) }
  let!(:verse_two) { create_verse(2, 7002) }

  let!(:single_resource) do
    ResourceContent.create!(
      name: 'Single Verse Tafsir',
      language_id: language.id,
      language_name: language.name,
      sub_type: ResourceContent::SubType::Tafsir,
      cardinality_type: ResourceContent::CardinalityType::OneVerse,
      resource_type: ResourceContent::ResourceType::Content,
      approved: true,
      permission_to_share: :granted,
      author: author,
      data_source: data_source
    )
  end

  let!(:multi_resource) do
    ResourceContent.create!(
      name: 'Multi Verse Tafsir',
      language_id: language.id,
      language_name: language.name,
      sub_type: ResourceContent::SubType::Tafsir,
      cardinality_type: ResourceContent::CardinalityType::NVerse,
      resource_type: ResourceContent::ResourceType::Content,
      approved: true,
      permission_to_share: :granted,
      author: author,
      data_source: data_source
    )
  end

  let!(:single_tafsir_one) { create_tafsir(verse_one, single_resource, 'Single tafsir verse 1') }
  let!(:single_tafsir_two) { create_tafsir(verse_two, single_resource, 'Single tafsir verse 2') }
  let!(:multi_tafsir_one) do
    create_tafsir(
      verse_one,
      multi_resource,
      'Multi tafsir covering verses 1-2',
      start_verse: verse_one,
      end_verse: verse_two,
      group_id: 700
    )
  end
  let!(:multi_tafsir_two) do
    create_tafsir(
      verse_two,
      multi_resource,
      'Multi tafsir covering verses 1-2',
      start_verse: verse_one,
      end_verse: verse_two,
      group_id: 700
    )
  end

  describe 'GET /api/v4/verses/by_chapter/:chapter_number' do
    it 'returns tafsirs for a single resource id param' do
      get endpoint, params: { language: 'en', tafsirs: single_resource.id }

      expect(response).to have_http_status(:ok)
      returned_ids = verse_level_tafsir_ids

      expect(returned_ids).to eq([single_resource.id])
    end

    it 'returns tafsirs for multiple comma separated resource ids' do
      params = { language: 'en', tafsirs: [single_resource.id, multi_resource.id].join(',') }
      get endpoint, params: params

      expect(response).to have_http_status(:ok)
      first_verse = response_json['verses'].find { |verse| verse['verse_key'] == verse_one.verse_key }

      expect(first_verse['tafsirs'].map { |t| t['resource_id'] }.sort).to eq([multi_resource.id, single_resource.id].sort)
    end

    it 'includes multi-verse tafsir ranges when requesting n_ayah resources' do
      get endpoint, params: { language: 'en', tafsirs: multi_resource.id }

      expect(response).to have_http_status(:ok)
      verses = response_json['verses']
      expect(verses.size).to eq(2)

      verses.each do |verse|
        tafsir = verse['tafsirs'].find { |entry| entry['resource_id'] == multi_resource.id }
        expect(tafsir).not_to be_nil
        expect(tafsir['text']).to eq('Multi tafsir covering verses 1-2')
      end
    end

    it 'does not return duplicate verses when a verse matches multiple tafsirs' do
      params = { language: 'en', tafsirs: [single_resource.id, multi_resource.id].join(',') }
      get endpoint, params: params

      expect(response).to have_http_status(:ok)
      verse_ids = response_json['verses'].map { |verse| verse['id'] }

      expect(verse_ids).to eq(verse_ids.uniq)
    end
  end

  def create_verse(number, index)
    Verse.create!(
      verse_number: number,
      verse_index: index,
      verse_key: "#{chapter.chapter_number}:#{number}",
      chapter: chapter,
      chapter_id: chapter.id,
      juz_number: 1,
      hizb_number: 1,
      rub_el_hizb_number: 1,
      ruku_number: 1,
      manzil_number: 1,
      page_number: 1,
      words_count: 1,
      mushaf_juzs_mapping: { 'madani' => 1 },
      mushaf_pages_mapping: { 'madani' => 1 },
      verse_root: verse_root,
      verse_lemma: verse_lemma,
      verse_stem: verse_stem
    )
  end

  def create_tafsir(verse, resource, text, start_verse: verse, end_verse: verse, group_id: nil)
    Tafsir.create!(
      verse: verse,
      chapter_id: chapter.id,
      verse_key: verse.verse_key,
      verse_number: verse.verse_number,
      hizb_number: verse.hizb_number,
      juz_number: verse.juz_number,
      rub_el_hizb_number: verse.rub_el_hizb_number,
      page_number: verse.page_number,
      manzil_number: verse.manzil_number,
      ruku_number: verse.ruku_number,
      text: text,
      language: language,
      language_name: language.name,
      resource_content: resource,
      resource_name: resource.name,
      group_tafsir_id: group_id,
      group_verse_key_from: start_verse.verse_key,
      group_verse_key_to: end_verse.verse_key,
      group_verses_count: (end_verse.verse_number - start_verse.verse_number).abs + 1,
      start_verse_id: start_verse.id,
      end_verse_id: end_verse.id
    )
  end

  def verse_level_tafsir_ids
    response_json['verses'].flat_map { |verse| verse['tafsirs'].map { |t| t['resource_id'] } }.uniq
  end
end
