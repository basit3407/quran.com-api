# frozen_string_literal: true

module Api
  module Qdc
    module Qiraat
      class ReadersController < BaseController
        # GET /api/qdc/qiraat/readers
        # Supports optional ?include parameter (comma-separated): transmitters, bio
        def index
          @includes = includes_param
          readers_scope = QiraatReader.includes(:localized_contents).order(:position)

          # Conditionally eager load based on includes parameter
          if @includes.include?('transmitters')
            readers_scope = readers_scope.includes(:qiraat_transmitters)
          end

          @readers = readers_scope.to_a
          render
        end

        # GET /api/qdc/qiraat/readers/:id
        def show
          @reader = QiraatReader.includes(
            :qiraat_transmitters,
            :localized_contents
          ).find(params[:id])

          render
        rescue ActiveRecord::RecordNotFound
          @error = {
            code: 'NOT_FOUND',
            message: "Reader with id #{params[:id]} not found"
          }
          render 'api/qdc/qiraat/error', status: :not_found
        end
      end
    end
  end
end
