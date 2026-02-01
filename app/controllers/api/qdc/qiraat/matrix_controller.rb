# frozen_string_literal: true

module Api
  module Qdc
    module Qiraat
      class MatrixController < BaseController
        # Allowed text fields for the matrix API
        ALLOWED_TEXT_FIELDS = %w[text_uthmani text_imlaei text_qpc_hafs].freeze

        # GET /api/qdc/qiraat/matrix/by_verse/:verse_key
        def by_verse
          verse_key = params[:verse_key]

          unless verse_key =~ /^\d+:\d+$/
            @error = {
              code: 'INVALID_PARAMETER',
              message: 'Invalid verse_key format. Expected format: chapter:verse (e.g., 12:12)',
              details: {
                parameter: 'verse_key',
                provided: verse_key,
                expected: '12:12'
              }
            }
            return render 'api/qdc/qiraat/error', status: :bad_request
          end

          @text_field = parse_text_field
          build_matrix_for_verse(verse_key)
          render formats: [:json] unless performed?
        end

        # GET /api/qdc/qiraat/matrix/by_chapter/:chapter_number
        def by_chapter
          @chapter = Chapter.find(params[:chapter_number])
          @text_field = parse_text_field

          # Query junctures via their segments
          # Only include approved junctures in public API
          base_scope = QiraatJuncture
            .approved
            .joins(qiraat_juncture_segments: :verse)
            .where(verses: { chapter_id: @chapter.id })
            .includes(matrix_includes)
            .distinct
            .order(:position)

          @total_count = base_scope.count
          @junctures = paginate(base_scope)
          @pagination = pagination_meta(@junctures, @total_count)
          @readers = all_readers
          @transmitters = all_transmitters
          render formats: [:json]
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Chapter #{params[:chapter_number]} not found"
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end

        # GET /api/qdc/qiraat/matrix/count_within_range?from=1:1&to=2:10
        def count_within_range
          # Validate parameters
          unless params[:from] && params[:to]
            @error = {
              code: 'INVALID_PARAMETER',
              message: 'Missing required parameters: from and to',
              details: {
                required: ['from', 'to']
              }
            }
            return render 'api/qdc/qiraat/error', status: :bad_request
          end

          # Parse and validate verse keys
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
            return render 'api/qdc/qiraat/error', status: :bad_request
          end

          # Convert verse keys to verse indices
          from_verse_index = QuranUtils::Quran.get_ayah_id_from_key(from_verse_key)
          to_verse_index = QuranUtils::Quran.get_ayah_id_from_key(to_verse_key)

          unless from_verse_index && to_verse_index
            @error = {
              code: 'INVALID_PARAMETER',
              message: 'Invalid verse keys. Verse keys must reference valid Quranic verses.',
              details: {}
            }
            return render 'api/qdc/qiraat/error', status: :bad_request
          end

          if from_verse_index > to_verse_index
            @error = {
              code: 'INVALID_PARAMETER',
              message: 'Invalid range: from verse must come before to verse',
              details: {}
            }
            return render 'api/qdc/qiraat/error', status: :bad_request
          end

          # Get verse count map
          @verse_counts = get_juncture_count_by_verse_range(from_verse_index, to_verse_index)
          render formats: [:json]
        end

        private

        def parse_text_field
          field = params[:text_field].to_s.strip
          return 'text_uthmani' if field.blank?

          # Normalize the field name
          normalized = field.start_with?('text_') ? field : "text_#{field}"
          ALLOWED_TEXT_FIELDS.include?(normalized) ? normalized : 'text_uthmani'
        end

        def build_matrix_for_verse(verse_key)
          chapter_num, verse_num = verse_key.split(':').map(&:to_i)
          @verse = Verse.find_by!(chapter_id: chapter_num, verse_number: verse_num)

          # Query junctures that have segments referencing this verse
          # Only include approved junctures in public API
          @junctures = QiraatJuncture
            .approved
            .joins(:qiraat_juncture_segments)
            .where(qiraat_juncture_segments: { verse_id: @verse.id })
            .includes(matrix_includes)
            .distinct
            .order(:position)

          if @junctures.empty?
            @error = {
              code: 'NOT_FOUND',
              message: "No qiraat variations found for verse #{verse_key}",
              details: {}
            }
            return render 'api/qdc/qiraat/error', status: :not_found
          end

          @readers = all_readers
          @transmitters = all_transmitters
          # View will handle rendering
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Verse #{verse_key} not found",
            details: {}
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end

        def all_readers
          @all_readers ||= QiraatReader.includes(:localized_contents).order(:position)
        end

        def all_transmitters
          @all_transmitters ||= QiraatTransmitter.includes(:qiraat_reader, :localized_contents)
                                                  .order('qiraat_readers.position', 'qiraat_transmitters.position')
        end

        def matrix_includes
          {
            qiraat_juncture_segments: [:verse, :start_word, :end_word],
            qiraat_readings: [
              :localized_contents,
              qiraat_reading_attributions: [:qiraat_reader, :qiraat_transmitter],
              qiraat_reading_explanations: :localized_contents,
              qiraat_reading_translations: :localized_contents
            ],
            localized_contents: []
          }
        end

        # Get juncture count per verse within a given verse index range
        # Returns a hash mapping verse keys to juncture counts
        # Only includes verses that have at least one juncture
        def get_juncture_count_by_verse_range(from_verse_index, to_verse_index)
          result = QiraatJuncture
            .approved
            .joins(qiraat_juncture_segments: :verse)
            .where(verses: { verse_index: from_verse_index..to_verse_index })
            .group('verses.verse_key')
            .pluck(Arel.sql('verses.verse_key, COUNT(DISTINCT qiraat_junctures.id)'))
            .to_h

          result
        end
      end
    end
  end
end
