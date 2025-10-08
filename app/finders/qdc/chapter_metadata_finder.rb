# frozen_string_literal: true

module Qdc
  class ChapterMetadataFinder < Finder

    def chapter
      strong_memoize :chapter do
        find_chapter(params[:id])
      end
    end

    def suggestions
      strong_memoize :suggestions do
        fetch_metadata_with_language(
          ChapterMetadata.active.suggestions.for_chapter(chapter.id)
        )
      end
    end

    def next_chapter
      strong_memoize :next_chapter do
        Chapter.find_by(id: chapter.id + 1)
      end
    end

    def previous_chapter
      strong_memoize :previous_chapter do
        Chapter.find_by(id: chapter.id - 1)
      end
    end

    def next_chapter_summaries
      strong_memoize :next_chapter_summaries do
        next_chapter ? fetch_summaries_for(next_chapter.id) : []
      end
    end

    def previous_chapter_summaries
      strong_memoize :previous_chapter_summaries do
        previous_chapter ? fetch_summaries_for(previous_chapter.id) : []
      end
    end

    private

    def fetch_summaries_for(chapter_id)
      fetch_metadata_with_language(
        ChapterMetadata.active.summaries.for_chapter(chapter_id)
      )
    end

    def fetch_metadata_with_language(scope)
      language_id = params[:language_id].presence || Language.default.id

      scope.includes(:language)
           .where(language_id: language_id)
           .order(created_at: :asc)
    end
  end
end
