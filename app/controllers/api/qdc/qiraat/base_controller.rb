# frozen_string_literal: true

module Api
  module Qdc
    module Qiraat
      class BaseController < Api::Qdc::ApiController
        before_action :set_language
        before_action :set_default_format

        private

        def set_default_format
          request.format = :json
        end

        def set_language
          @language = Language.find_by(iso_code: params[:language] || 'en') || Language.find_by(iso_code: 'en')
        end

        def cache_key_for(*parts)
          "qiraat:#{parts.join(':')}:#{@language.iso_code}:v1"
        end

        def paginate(collection, default_per_page: 20, max_per_page: 100)
          page = params[:page]&.to_i || 1
          per_page = [params[:per_page]&.to_i || default_per_page, max_per_page].min

          # Simple offset/limit pagination since we don't need pagy's full features
          collection.limit(per_page).offset((page - 1) * per_page)
        end

        def includes_param
          @includes_param ||= (params[:include] || '').split(',').map(&:strip).compact
        end

        def pagination_meta(collection, total_count)
          per_page = params[:per_page]&.to_i || 20
          current_page = params[:page]&.to_i || 1
          {
            current_page: current_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count,
            per_page: per_page
          }
        end
      end
    end
  end
end
