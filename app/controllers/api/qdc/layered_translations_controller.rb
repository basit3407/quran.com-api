# frozen_string_literal: true

module Api
  module Qdc
    class LayeredTranslationsController < ApiController
      before_action :set_default_format
      before_action :set_languages

      # GET /api/qdc/layered_translations/by_verse/:verse_key
      def by_verse
        verse_key = params[:verse_key].to_s.strip

        unless verse_key.match?(/^\d+:\d+$/)
          return render_error(
            :bad_request,
            'INVALID_PARAMETER',
            'Invalid verse_key format. Expected format: chapter:verse (e.g., 67:1)',
            parameter: 'verse_key',
            provided: verse_key
          )
        end

        @verse = Verse.find_by(verse_key: verse_key)
        return render_error(:not_found, 'NOT_FOUND', "Verse #{verse_key} not found") unless @verse

        @resource, @fallback_used = resolve_resource
        return render_error(:not_found, 'NOT_FOUND', 'No layered translation resource found') unless @resource

        @layered_translation_ayah = LayeredTranslationAyah
                                    .includes(
                                      layered_translation_groups: [
                                        :layered_translation_options
                                      ]
                                    )
                                    .find_by(resource_content_id: @resource.id, verse_id: @verse.id)

        unless @layered_translation_ayah
          return render_error(
            :not_found,
            'NOT_FOUND',
            "No layered translation found for verse #{verse_key} in resource #{@resource.id}"
          )
        end

        @groups = @layered_translation_ayah.layered_translation_groups.sort_by { |group| [group.position || Float::INFINITY, group.id] }
        render formats: [:json]
      end

      # GET /api/qdc/layered_translations/count_within_range?from=1:1&to=1:20&resource_id=123
      def count_within_range
        @verse_counts = {}

        from_key = params[:from].to_s.strip
        to_key = params[:to].to_s.strip

        unless from_key.present? && to_key.present?
          return render_error(
            :bad_request,
            'INVALID_PARAMETER',
            'Missing required parameters: from and to',
            required: ['from', 'to']
          )
        end

        unless from_key.match?(/^\d+:\d+$/) && to_key.match?(/^\d+:\d+$/)
          return render_error(
            :bad_request,
            'INVALID_PARAMETER',
            'Invalid verse_key format. Expected format: chapter:verse (e.g., 1:1)',
            from: from_key,
            to: to_key,
            expected: '1:1'
          )
        end

        from_verse_index = QuranUtils::Quran.get_ayah_id_from_key(from_key)
        to_verse_index = QuranUtils::Quran.get_ayah_id_from_key(to_key)

        unless from_verse_index && to_verse_index
          return render_error(
            :bad_request,
            'INVALID_PARAMETER',
            'Invalid verse keys. Verse keys must reference valid Quranic verses.',
            from: from_key,
            to: to_key
          )
        end

        if from_verse_index > to_verse_index
          return render_error(
            :bad_request,
            'INVALID_PARAMETER',
            'Invalid range: from verse must come before to verse',
            from: from_key,
            to: to_key
          )
        end

        @resource, = resolve_resource
        if @resource.blank?
          return render formats: [:json]
        end

        @verse_counts = LayeredTranslationAyah
                        .joins(:verse)
                        .where(resource_content_id: @resource.id, verses: { verse_index: from_verse_index..to_verse_index })
                        .group('verses.verse_key')
                        .pluck(Arel.sql('verses.verse_key, COUNT(layered_translation_ayahs.id)'))
                        .to_h
                        .transform_values { |count| count.positive? ? 1 : 0 }

        render formats: [:json]
      end

      private

      def set_default_format
        request.format = :json
      end

      def set_languages
        @english_language = Language.find_by(iso_code: 'en')
        @requested_language = Language.find_by(iso_code: params[:language].presence || 'en') || @english_language
      end

      def layered_resource_scope
        ResourceContent
          .layered_translations
          .one_verse
          .approved
          .allowed_to_host
      end

      def resolve_resource
        if params[:resource_id].present?
          return [layered_resource_scope.find_by(id: params[:resource_id].to_i), false]
        end

        preferred = layered_resource_scope.find_by(language_id: @requested_language&.id)
        return [preferred, false] if preferred.present?

        # Only fallback to English if the requested language is NOT Arabic
        return [nil, false] if @requested_language&.iso_code == 'ar'

        fallback = layered_resource_scope.find_by(language_id: @english_language&.id)
        [fallback, fallback.present? && @requested_language&.id != @english_language&.id]
      end

      def render_error(status, code, message, details = nil)
        @error = {
          code: code,
          message: message,
          details: details
        }

        render 'api/qdc/qiraat/error', status: status
      end
    end
  end
end
