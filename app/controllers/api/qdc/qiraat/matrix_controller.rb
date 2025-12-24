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
          base_scope = QiraatJuncture
            .joins(:qiraat_juncture_segments)
            .joins('INNER JOIN verses ON verses.id = qiraat_juncture_segments.verse_id')
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
          @junctures = QiraatJuncture
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
      end
    end
  end
end
