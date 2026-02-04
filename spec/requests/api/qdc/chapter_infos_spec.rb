# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'QDC Chapter Info API', type: :request do
  let(:endpoint) { "/api/qdc/chapters/#{chapter.id}/info" }

  let!(:english) do
    Language.find_or_create_by!(iso_code: 'en').tap do |language|
      language.update!(name: 'English') if language.name != 'English'
    end
  end
  let!(:arabic) do
    Language.find_or_create_by!(iso_code: 'ar').tap do |language|
      language.update!(name: 'Arabic') if language.name != 'Arabic'
    end
  end
  let!(:bangla) do
    Language.find_or_create_by!(iso_code: 'bn').tap do |language|
      language.update!(name: 'Bangla') if language.name != 'Bangla'
    end
  end

  let!(:author) { Author.create!(name: 'Spec Author') }
  let!(:data_source) { DataSource.create!(name: 'Spec Source') }

  let!(:chapter) do
    Chapter.create!(
      chapter_number: 999,
      name_simple: 'Spec Chapter',
      name_complex: 'Spec Chapter',
      name_arabic: 'Spec Arabic',
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

  let!(:english_resource_primary) do
    ResourceContent.create!(
      name: 'Primary Info',
      language_id: english.id,
      language_name: english.name,
      sub_type: ResourceContent::SubType::Info,
      cardinality_type: ResourceContent::CardinalityType::OneChapter,
      resource_type: ResourceContent::ResourceType::Content,
      priority: 1,
      approved: true,
      permission_to_share: :granted,
      author: author,
      data_source: data_source
    )
  end

  let!(:english_resource_secondary) do
    ResourceContent.create!(
      name: 'Secondary Info',
      language_id: english.id,
      language_name: english.name,
      sub_type: ResourceContent::SubType::Info,
      cardinality_type: ResourceContent::CardinalityType::OneChapter,
      resource_type: ResourceContent::ResourceType::Content,
      priority: 2,
      approved: true,
      permission_to_share: :granted,
      author: author,
      data_source: data_source
    )
  end

  let!(:english_info_primary) do
    ChapterInfo.create!(
      chapter: chapter,
      language: english,
      language_name: english.name,
      resource_content: english_resource_primary,
      text: 'Primary info',
      short_text: 'Primary short',
      source: 'Spec source'
    )
  end

  let!(:english_info_secondary) do
    ChapterInfo.create!(
      chapter: chapter,
      language: english,
      language_name: english.name,
      resource_content: english_resource_secondary,
      text: 'Secondary info',
      short_text: 'Secondary short',
      source: 'Spec source'
    )
  end

  describe 'GET /api/qdc/chapters/:id/info' do
    it 'defaults to English and returns the highest priority resource when no params' do
      get endpoint

      expect(response).to have_http_status(:ok)
      chapter_info = response_json['chapter_info']

      expect(chapter_info['resourceId']).to eq(english_resource_primary.id)
      expect(chapter_info['text']).to eq('Primary info')
      expect(response_json).not_to have_key('resources')
    end

    it 'falls back to English when the requested language has no resources' do
      get endpoint, params: { language: 'bn' }

      expect(response).to have_http_status(:ok)
      chapter_info = response_json['chapter_info']

      expect(chapter_info['resourceId']).to eq(english_resource_primary.id)
      expect(chapter_info['language_name']).to eq('English')
    end

    it 'returns null when requested language is Arabic and no resources exist' do
      get endpoint, params: { language: 'ar' }

      expect(response).to have_http_status(:ok)
      expect(response_json['chapter_info']).to be_nil
    end

    it 'returns null when resource_id is not available' do
      get endpoint, params: { language: 'en', resource_id: 999_999 }

      expect(response).to have_http_status(:ok)
      expect(response_json['chapter_info']).to be_nil
    end

    it 'resolves resource_id after language fallback' do
      get endpoint, params: { language: 'bn', resource_id: english_resource_secondary.id }

      expect(response).to have_http_status(:ok)
      chapter_info = response_json['chapter_info']

      expect(chapter_info['resourceId']).to eq(english_resource_secondary.id)
      expect(chapter_info['text']).to eq('Secondary info')
    end

    it 'returns resources for the requested language when include_resources is true' do
      get endpoint, params: { language: 'en', include_resources: 'true' }

      expect(response).to have_http_status(:ok)
      resources = response_json['resources']

      expect(resources.map { |resource| resource['id'] }).to eq([
        english_resource_primary.id,
        english_resource_secondary.id
      ])
    end

    it 'falls back resources to English when include_resources is true and language has no data' do
      get endpoint, params: { language: 'bn', include_resources: 'true' }

      expect(response).to have_http_status(:ok)
      resources = response_json['resources']

      expect(resources.map { |resource| resource['id'] }).to eq([
        english_resource_primary.id,
        english_resource_secondary.id
      ])
    end

    it 'does not fallback resources for Arabic when include_resources is true' do
      get endpoint, params: { language: 'ar', include_resources: 'true' }

      expect(response).to have_http_status(:ok)
      resources = response_json['resources']

      expect(resources).to be_nil.or eq([])
    end
  end
end
