# frozen_string_literal: true

module Api::Qdc
  class ChapterMetadataController < ApiController
    before_action :init_presenter
    before_action :validate_chapter

    def metadata
      render
    end

    private

    def init_presenter
      @presenter = Qdc::ChapterMetadataPresenter.new(permitted_params)
    end

    def permitted_params
      params.permit(:id, :language, :locale, :format)
    end

    def validate_chapter
      @presenter.chapter
    end
  end
end
