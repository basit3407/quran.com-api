# frozen_string_literal: true

module Api::V4
  class Audio::RecitationsController < ApiController
    before_action :init_presenter, except: [:timestamp, :lookup_ayah]

    def index
      render
    end

    def show
      render
    end

    def related
      render
    end

    def audio_files
      render
    end

    def timestamp
      @presenter = ::Audio::SegmentPresenter.new(params)

      render
    end

    def lookup_ayah
      @presenter = ::Audio::SegmentPresenter.new(params)

      render
    end

    protected
    def init_presenter
      @presenter = ::Audio::RecitationPresenter.new(params)
    end
  end
end
