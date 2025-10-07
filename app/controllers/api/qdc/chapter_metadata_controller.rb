# frozen_string_literal: true

module Api::Qdc
  class ChapterMetadataController < ApiController
    before_action :init_finder
    before_action :validate_chapter

    def metadata
      render
    end

    private

    def init_finder
      @finder = Qdc::ChapterMetadataFinder.new(permitted_params)
    end

    def permitted_params
      params.permit(:id, :language, :locale, :format)
    end

    def validate_chapter
      @finder.chapter
    end
  end
end
