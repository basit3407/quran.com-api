# frozen_string_literal: true

module Api::Qdc
  class HadithReferencesController < ApiController
    before_action :set_language

    # GET /api/qdc/hadith_references/by_ayah/:ayah_key
    def by_ayah
      ayah_key = params[:ayah_key].to_s.strip

      unless ayah_key =~ /^\d+:\d+$/
        @error = {
          code: 'INVALID_PARAMETER',
          message: 'Invalid ayah_key format. Expected format: chapter:verse (e.g., 12:12)',
          details: {
            parameter: 'ayah_key',
            provided: ayah_key,
            expected: '12:12'
          }
        }
        return render 'api/qdc/hadith_references/error', status: :bad_request
      end

      @verse = Verse.find_by(verse_key: ayah_key)
      unless @verse
        @error = {
          code: 'NOT_FOUND',
          message: "Verse #{ayah_key} not found",
          details: {}
        }
        return render 'api/qdc/hadith_references/error', status: :not_found
      end

      @references = HadithReference
        .for_verse_index(@verse.verse_index)
        .order(:collection, :our_hadith_number, :ayah_start_index, :ayah_end_index)
        .to_a

      render formats: [:json]
    end

    # GET /api/qdc/hadith_references/by_ayah/:ayah_key/hadiths
    def hadiths
      ayah_key = params[:ayah_key].to_s.strip

      unless ayah_key =~ /^\d+:\d+$/
        @error = {
          code: 'INVALID_PARAMETER',
          message: 'Invalid ayah_key format. Expected format: chapter:verse (e.g., 12:12)',
          details: {
            parameter: 'ayah_key',
            provided: ayah_key,
            expected: '12:12'
          }
        }
        return render 'api/qdc/hadith_references/error', status: :bad_request
      end

      @verse = Verse.find_by(verse_key: ayah_key)
      unless @verse
        @error = {
          code: 'NOT_FOUND',
          message: "Verse #{ayah_key} not found",
          details: {}
        }
        return render 'api/qdc/hadith_references/error', status: :not_found
      end

      reference_scope = HadithReference
        .for_verse_index(@verse.verse_index)
        .order(:collection, :our_hadith_number, :ayah_start_index, :ayah_end_index)

      @limit = limit_param
      @page = page_param
      offset = (@page - 1) * @limit

      references = reference_scope.limit(@limit + 1).offset(offset).to_a
      @has_more = references.length > @limit
      @references = references.first(@limit)

      requested_language = params[:language].to_s.downcase
      use_arabic = requested_language == 'ar'
      urns = @references.map { |reference| use_arabic ? reference.arabic_urn : reference.english_urn }.compact

      if urns.empty?
        @hadiths = []
      else
        begin
          hadith_response = SunnahApi.instance.hadith_by_urns(urns, language: (use_arabic ? 'ar' : @language.iso_code))
        rescue ArgumentError => e
          @error = {
            code: 'CONFIGURATION_ERROR',
            message: e.message,
            details: {}
          }
          return render 'api/qdc/hadith_references/error', status: :internal_server_error
        end

        if hadith_response.is_a?(Hash) && hadith_response['status']
          @error = {
            code: 'UPSTREAM_ERROR',
            message: hadith_response['message'],
            details: {
              status: hadith_response['status']
            }
          }
          return render 'api/qdc/hadith_references/error', status: :bad_gateway
        end

        @hadiths = if hadith_response.is_a?(Hash) && hadith_response['data'].is_a?(Array)
          hadith_response['data']
        else
          []
        end
      end

      render formats: [:json]
    end

    # GET /api/qdc/hadith_references/count_within_range?from=1:1&to=2:10
    def count_within_range
      unless params[:from] && params[:to]
        @error = {
          code: 'INVALID_PARAMETER',
          message: 'Missing required parameters: from and to',
          details: {
            required: ['from', 'to']
          }
        }
        return render 'api/qdc/hadith_references/error', status: :bad_request
      end

      from_verse_key = params[:from].to_s.strip
      to_verse_key = params[:to].to_s.strip

      unless from_verse_key =~ /^\d+:\d+$/ && to_verse_key =~ /^\d+:\d+$/
        @error = {
          code: 'INVALID_PARAMETER',
          message: 'Invalid verse_key format. Expected format: chapter:verse (e.g., 1:1)',
          details: {
            from: from_verse_key,
            to: to_verse_key,
            expected: '1:1'
          }
        }
        return render 'api/qdc/hadith_references/error', status: :bad_request
      end

      from_verse_index = QuranUtils::Quran.get_ayah_id_from_key(from_verse_key)
      to_verse_index = QuranUtils::Quran.get_ayah_id_from_key(to_verse_key)

      unless from_verse_index && to_verse_index
        @error = {
          code: 'INVALID_PARAMETER',
          message: 'Invalid verse keys. Verse keys must reference valid Quranic verses.',
          details: {}
        }
        return render 'api/qdc/hadith_references/error', status: :bad_request
      end

      if from_verse_index > to_verse_index
        @error = {
          code: 'INVALID_PARAMETER',
          message: 'Invalid range: from verse must come before to verse',
          details: {}
        }
        return render 'api/qdc/hadith_references/error', status: :bad_request
      end

      @verse_counts = Verse
        .unscope(:order)
        .where(verse_index: from_verse_index..to_verse_index)
        .joins(<<~SQL.squish)
          INNER JOIN hadith_references
          ON verses.verse_index BETWEEN hadith_references.ayah_start_index
          AND hadith_references.ayah_end_index
        SQL
        .group('verses.verse_key')
        .pluck(Arel.sql('verses.verse_key, COUNT(hadith_references.id)'))
        .to_h

      render formats: [:json]
    end

    private

    def set_language
      @language = Language.find_with_id_or_iso_code(params[:language] || 'en') || Language.default
    end

    def page_param
      page = params[:page].to_i
      page.positive? ? page : 1
    end

    def limit_param
      limit = (params[:limit] || 4).to_i
      limit.clamp(1, 5)
    end    
  end
end
