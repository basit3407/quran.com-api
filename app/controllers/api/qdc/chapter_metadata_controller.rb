# frozen_string_literal: true

module Api::Qdc
  class ChapterMetadataController < ApiController
    before_action :init_presenter
    before_action :validate_chapter

    def metadata
      render
    end

    protected

    def init_presenter
      @presenter = Qdc::ChapterMetadataPresenter.new(chapter_metadata_params, fetch_locale)
    end

    def chapter_metadata_params
      params.permit(:id, :language, :locale)
    end

    def validate_chapter
      @presenter.chapter
    end
  end
end
