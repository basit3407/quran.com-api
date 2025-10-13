# frozen_string_literal: true

module Qdc
  class ChapterMetadataPresenter < BasePresenter
    delegate :chapter,
             :suggestions,
             :next_chapter,
             :previous_chapter,
             :next_chapter_summaries,
             :previous_chapter_summaries,
             to: :finder

    attr_reader :finder

    def initialize(params)
      super(params)
      lang_id = (language&.id || Language.default.id)
      @finder = Qdc::ChapterMetadataFinder.new(params.merge(language_id: lang_id))
    end
  end
end
