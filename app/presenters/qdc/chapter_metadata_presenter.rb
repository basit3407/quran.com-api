# frozen_string_literal: true

module Qdc
  class ChapterMetadataPresenter < BasePresenter
    delegate :chapter, :chapter_id, :suggestions, :next_chapter, :previous_chapter, :next_chapter_summaries, :previous_chapter_summaries, to: :finder

    attr_reader :finder

    def initialize(params, locale = nil)
      super(params)
      locale ||= fetch_locale
      @finder = Qdc::ChapterMetadataFinder.new(params.merge(language: locale))
    end
  end
end
