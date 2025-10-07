# frozen_string_literal: true

module Qdc
  class ChapterMetadataPresenter < BasePresenter
    delegate :chapter,
             :chapter_id,
             :suggestions,
             :next_chapter,
             :previous_chapter,
             :next_chapter_summaries,
             :previous_chapter_summaries,
             to: :finder

    attr_reader :finder

    def initialize(params)
      super(params)
      @finder = Qdc::ChapterMetadataFinder.new(params)
    end
  end
end
