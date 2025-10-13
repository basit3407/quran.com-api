# frozen_string_literal: true

module Api::Qdc
  class ChapterMetadataController < ApiController
    before_action :init_presenter

    def metadata
      render
    end

    protected

    def init_presenter
      @presenter = Qdc::ChapterMetadataPresenter.new(params)
    end
  end
end
