# frozen_string_literal: true

module Api
  module Qdc
    module Qiraat
      class TransmittersController < BaseController
        # GET /api/qdc/qiraat/transmitters
        # Supports optional ?reader_id parameter to filter by reader
        def index
          @transmitters = QiraatTransmitter.includes(:qiraat_reader).order(:position)

          # Filter by reader_id if provided
          if params[:reader_id].present?
            @transmitters = @transmitters.where(qiraat_reader_id: params[:reader_id])
          end

          @transmitters = @transmitters.to_a
          render
        end

        # GET /api/qdc/qiraat/transmitters/:id
        def show
          @transmitter = QiraatTransmitter.includes(:qiraat_reader, :localized_contents)
                                          .find(params[:id])

          render
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Transmitter with id #{params[:id]} not found"
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end
      end
    end
  end
end
