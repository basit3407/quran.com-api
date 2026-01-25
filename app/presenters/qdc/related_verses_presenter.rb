# frozen_string_literal: true

module Qdc
  class RelatedVersesPresenter < BasePresenter
    def initialize(params, action_name)
      super(params)
      @finder = Qdc::RelatedVersesFinder.new(params)
    end

    def related_verses
      strong_memoize :related_verses do
        finder.load_related_verses
      end
    end

    def chapters
      finder.chapters
    end

    def find_verse
      finder.find_verse
    end

    def get_language
      finder.language
    end

    def pagination
      {
        current_page: finder.current_page,
        next_page: finder.next_page,
        total_pages: finder.total_pages,
        total_count: finder.total_records,
        per_page: finder.per_page
      }
    end
  end
end

