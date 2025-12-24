# frozen_string_literal: true

module Api
  module Qdc
    module Qiraat
      class JuncturesController < BaseController
        # GET /api/qdc/qiraat/junctures/by_verse/:verse_key
        def by_verse
          verse_key = params[:verse_key]
          chapter_num, verse_num = verse_key.split(':').map(&:to_i)

          @verse = Verse.find_by!(chapter_id: chapter_num, verse_number: verse_num)

          # Only include approved junctures in public API
          @junctures = QiraatJuncture.approved
                                     .for_verse(@verse.id)
                                     .includes(:localized_contents)
                                     .order(:position)

          @includes = includes_param
          if @includes.include?('readings')
            @junctures = @junctures.includes(
              qiraat_readings: [
                :localized_contents,
                { qiraat_reading_explanations: :localized_contents }
              ]
            )
          end

          render
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Verse #{verse_key} not found"
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end

        # GET /api/qdc/qiraat/junctures/by_chapter/:chapter_number
        def by_chapter
          @chapter = Chapter.find(params[:chapter_number])

          # Use scope to join through segments
          # Only include approved junctures in public API
          base_scope = QiraatJuncture.approved
                                     .for_chapter(@chapter.id)
                                     .includes(:localized_contents)
                                     .order(:position)

          @total_count = base_scope.count
          @junctures = paginate(base_scope)
          @pagination = pagination_meta(@junctures, @total_count)

          render
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Chapter #{params[:chapter_number]} not found"
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end

        # GET /api/qdc/qiraat/junctures/:id
        def show
          # Only include approved junctures in public API
          @juncture = QiraatJuncture.approved.includes(
            :localized_contents,
            { qiraat_juncture_segments: :verse },
            qiraat_readings: [
              :localized_contents,
              :qiraat_reading_attributions,
              { qiraat_reading_explanations: :localized_contents }
            ]
          ).find(params[:id])

          @includes = includes_param

          render
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Juncture with id #{params[:id]} not found"
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end
      end
    end
  end
end
