# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'QDC Chapter Metadata API', type: :request do
  let(:english) { Language.find_by(iso_code: 'en') }
  let(:arabic) { Language.find_by(iso_code: 'ar') }

  before do
    ChapterMetadata.delete_all
    Language.find_or_create_by!(iso_code: 'en', name: 'English')
    Language.find_or_create_by!(iso_code: 'ar', name: 'Arabic')
  end

  describe 'GET /api/qdc/chapters/:id/metadata' do
    context 'valid chapter ID' do
      context 'with suggestions and summaries' do
        let!(:suggestion_en) do
          ChapterMetadata.create!(
            chapter_id: 1,
            metadata_type: 'suggestion',
            content: 'Read this chapter when seeking guidance.',
            language_id: english.id,
            is_active: true
          )
        end

        let!(:suggestion_ar) do
          ChapterMetadata.create!(
            chapter_id: 1,
            metadata_type: 'suggestion',
            content: 'اقرأ هذه السورة عند طلب الهداية.',
            language_id: arabic.id,
            is_active: true
          )
        end

        let!(:next_chapter_summary_en) do
          ChapterMetadata.create!(
            chapter_id: 2,
            metadata_type: 'summary',
            content: 'This chapter emphasizes faith.',
            language_id: english.id,
            is_active: true
          )
        end

        let!(:next_chapter_summary_ar) do
          ChapterMetadata.create!(
            chapter_id: 2,
            metadata_type: 'summary',
            content: 'تركز هذه السورة على الإيمان.',
            language_id: arabic.id,
            is_active: true
          )
        end

        it 'returns English metadata when language=en' do
          get '/api/qdc/chapters/1/metadata', params: { language: 'en' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['chapter_id']).to eq(1)
          expect(json['chapter_metadata']['suggestions'].size).to eq(1)
          expect(json['chapter_metadata']['suggestions'][0]['id']).to eq(suggestion_en.id)
          expect(json['chapter_metadata']['suggestions'][0]['language_name']).to eq('English')
          expect(json['chapter_metadata']['suggestions'][0]['text']).to eq('Read this chapter when seeking guidance.')
        end

        it 'returns Arabic metadata when language=ar' do
          get '/api/qdc/chapters/1/metadata', params: { language: 'ar' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['suggestions'].size).to eq(1)
          expect(json['chapter_metadata']['suggestions'][0]['id']).to eq(suggestion_ar.id)
          expect(json['chapter_metadata']['suggestions'][0]['language_name']).to eq('Arabic')
          expect(json['chapter_metadata']['suggestions'][0]['text']).to eq('اقرأ هذه السورة عند طلب الهداية.')
        end

        it 'returns next chapter summaries in requested language' do
          get '/api/qdc/chapters/1/metadata', params: { language: 'ar' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['next_chapter']).not_to be_nil
          expect(json['chapter_metadata']['next_chapter']['summaries'].size).to eq(1)
          expect(json['chapter_metadata']['next_chapter']['summaries'][0]['language_name']).to eq('Arabic')
          expect(json['chapter_metadata']['next_chapter']['summaries'][0]['text']).to eq('تركز هذه السورة على الإيمان.')
        end

        it 'returns previous_chapter as null for chapter 1' do
          get '/api/qdc/chapters/1/metadata', params: { language: 'en' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['previous_chapter']).to be_nil
        end

        it 'returns correct JSON structure with field order' do
          get '/api/qdc/chapters/1/metadata', params: { language: 'en' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          suggestion = json['chapter_metadata']['suggestions'][0]
          expect(suggestion.keys).to eq(['id', 'language_name', 'text'])
        end
      end

      context 'language fallback' do
        let!(:suggestion_en_only) do
          ChapterMetadata.create!(
            chapter_id: 50,
            metadata_type: 'suggestion',
            content: 'English only suggestion.',
            language_id: english.id,
            is_active: true
          )
        end

        it 'falls back to English when requested language has no data' do
          get '/api/qdc/chapters/50/metadata', params: { language: 'fr' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['suggestions'].size).to eq(1)
          expect(json['chapter_metadata']['suggestions'][0]['language_name']).to eq('English')
          expect(json['chapter_metadata']['suggestions'][0]['text']).to eq('English only suggestion.')
        end

        it 'returns empty arrays when no data exists in any language' do
          get '/api/qdc/chapters/100/metadata', params: { language: 'ar' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['suggestions']).to eq([])
        end
      end

      context 'chapter 114 (last chapter)' do
        let!(:suggestion_114) do
          ChapterMetadata.create!(
            chapter_id: 114,
            metadata_type: 'suggestion',
            content: 'Final chapter suggestion.',
            language_id: english.id,
            is_active: true
          )
        end

        let!(:summary_113) do
          ChapterMetadata.create!(
            chapter_id: 113,
            metadata_type: 'summary',
            content: 'Previous chapter summary.',
            language_id: english.id,
            is_active: true
          )
        end

        it 'returns next_chapter as null' do
          get '/api/qdc/chapters/114/metadata', params: { language: 'en' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['chapter_id']).to eq(114)
          expect(json['chapter_metadata']['next_chapter']).to be_nil
        end

        it 'returns previous chapter summaries' do
          get '/api/qdc/chapters/114/metadata', params: { language: 'en' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['previous_chapter']).not_to be_nil
          expect(json['chapter_metadata']['previous_chapter']['summaries'].size).to eq(1)
          expect(json['chapter_metadata']['previous_chapter']['summaries'][0]['text']).to eq('Previous chapter summary.')
        end
      end

      context 'inactive metadata' do
        let!(:active_suggestion) do
          ChapterMetadata.create!(
            chapter_id: 5,
            metadata_type: 'suggestion',
            content: 'Active suggestion.',
            language_id: english.id,
            is_active: true
          )
        end

        let!(:inactive_suggestion) do
          ChapterMetadata.create!(
            chapter_id: 5,
            metadata_type: 'suggestion',
            content: 'Inactive suggestion.',
            language_id: english.id,
            is_active: false
          )
        end

        it 'returns only active metadata' do
          get '/api/qdc/chapters/5/metadata', params: { language: 'en' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['suggestions'].size).to eq(1)
          expect(json['chapter_metadata']['suggestions'][0]['text']).to eq('Active suggestion.')
        end
      end

      context 'multiple metadata items ordering' do
        let!(:older_suggestion) do
          ChapterMetadata.create!(
            chapter_id: 10,
            metadata_type: 'suggestion',
            content: 'First suggestion (older).',
            language_id: english.id,
            is_active: true,
            created_at: 2.days.ago
          )
        end

        let!(:newer_suggestion) do
          ChapterMetadata.create!(
            chapter_id: 10,
            metadata_type: 'suggestion',
            content: 'Second suggestion (newer).',
            language_id: english.id,
            is_active: true,
            created_at: 1.day.ago
          )
        end

        it 'returns metadata ordered by created_at ASC' do
          get '/api/qdc/chapters/10/metadata', params: { language: 'en' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['suggestions'].size).to eq(2)
          expect(json['chapter_metadata']['suggestions'][0]['text']).to eq('First suggestion (older).')
          expect(json['chapter_metadata']['suggestions'][1]['text']).to eq('Second suggestion (newer).')
        end
      end

      context 'locale parameter alias' do
        let!(:suggestion) do
          ChapterMetadata.create!(
            chapter_id: 20,
            metadata_type: 'suggestion',
            content: 'Test suggestion.',
            language_id: arabic.id,
            is_active: true
          )
        end

        it 'accepts locale parameter as alias for language' do
          get '/api/qdc/chapters/20/metadata', params: { locale: 'ar' }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['chapter_metadata']['suggestions'][0]['language_name']).to eq('Arabic')
        end
      end
    end

    context 'invalid chapter ID' do
      it 'returns 404 for chapter 0' do
        get '/api/qdc/chapters/0/metadata'

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)

        expect(json['status']).to eq(404)
        expect(json['error']).to be_a(String)
        expect(json['error']).not_to be_empty
      end

      it 'returns 404 for chapter 115' do
        get '/api/qdc/chapters/115/metadata'

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)

        expect(json['status']).to eq(404)
        expect(json['error']).to be_a(String)
        expect(json['error']).not_to be_empty
      end

      it 'returns 404 for chapter 999' do
        get '/api/qdc/chapters/999/metadata'

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['status']).to eq(404)

        expect(json['error']).to be_a(String)
        expect(json['error']).not_to be_empty
      end

      it 'returns 404 for negative chapter ID' do
        get '/api/qdc/chapters/-1/metadata'

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['status']).to eq(404)
        expect(json['error']).to be_a(String)
        expect(json['error']).not_to be_empty
      end
    end

    context 'edge cases' do
      it 'defaults to English when no language parameter provided' do
        ChapterMetadata.create!(
          chapter_id: 30,
          metadata_type: 'suggestion',
          content: 'Default English suggestion.',
          language_id: english.id,
          is_active: true
        )

        get '/api/qdc/chapters/30/metadata'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['chapter_metadata']['suggestions'][0]['language_name']).to eq('English')
      end

      it 'handles invalid language code gracefully' do
        ChapterMetadata.create!(
          chapter_id: 40,
          metadata_type: 'suggestion',
          content: 'Fallback to English.',
          language_id: english.id,
          is_active: true
        )

        get '/api/qdc/chapters/40/metadata', params: { language: 'xyz' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['chapter_metadata']['suggestions'][0]['language_name']).to eq('English')
      end

      it 'handles chapter with only summaries (no suggestions)' do
        ChapterMetadata.create!(
          chapter_id: 60,
          metadata_type: 'summary',
          content: 'Summary only.',
          language_id: english.id,
          is_active: true
        )

        get '/api/qdc/chapters/60/metadata', params: { language: 'en' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['chapter_metadata']['suggestions']).to eq([])
      end

      it 'returns valid JSON for chapter with no metadata at all' do
        get '/api/qdc/chapters/70/metadata'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['chapter_metadata']['chapter_id']).to eq(70)
        expect(json['chapter_metadata']['suggestions']).to eq([])
        expect(json['chapter_metadata']['next_chapter']).not_to be_nil
        expect(json['chapter_metadata']['previous_chapter']).not_to be_nil
      end
    end

    context 'response structure validation' do
      let!(:test_metadata) do
        ChapterMetadata.create!(
          chapter_id: 80,
          metadata_type: 'suggestion',
          content: 'Test content.',
          language_id: english.id,
          is_active: true
        )
      end

      it 'returns correct root structure' do
        get '/api/qdc/chapters/80/metadata'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json.keys).to eq(['chapter_metadata'])
        expect(json['chapter_metadata'].keys).to contain_exactly('chapter_id', 'suggestions', 'next_chapter', 'previous_chapter')
      end

      it 'returns suggestions with correct structure' do
        get '/api/qdc/chapters/80/metadata'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        suggestion = json['chapter_metadata']['suggestions'][0]
        expect(suggestion.keys).to eq(['id', 'language_name', 'text'])
        expect(suggestion['id']).to be_a(Integer)
        expect(suggestion['language_name']).to be_a(String)
        expect(suggestion['text']).to be_a(String)
      end

      it 'returns next_chapter with summaries structure' do
        ChapterMetadata.create!(
          chapter_id: 81,
          metadata_type: 'summary',
          content: 'Next summary.',
          language_id: english.id,
          is_active: true
        )

        get '/api/qdc/chapters/80/metadata'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['chapter_metadata']['next_chapter']).to have_key('summaries')
        expect(json['chapter_metadata']['next_chapter']['summaries']).to be_an(Array)
      end
    end
  end
end
