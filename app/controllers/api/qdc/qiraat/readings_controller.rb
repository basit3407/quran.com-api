# frozen_string_literal: true

module Api
  module Qdc
    module Qiraat
      class ReadingsController < BaseController
        # GET /api/qdc/qiraat/readings/:id
        def show
          @reading = QiraatReading.includes(
            :qiraat_juncture,
            :localized_contents,
            { qiraat_reading_attributions: [:qiraat_reader, :qiraat_transmitter] },
            qiraat_reading_explanations: :localized_contents
          ).find(params[:id])

          # Return 404 if the reading's juncture is not approved
          unless @reading.qiraat_juncture&.approved?
            raise ActiveRecord::RecordNotFound
          end

          render
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Reading with id #{params[:id]} not found"
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end
      end
    end
  end
end

