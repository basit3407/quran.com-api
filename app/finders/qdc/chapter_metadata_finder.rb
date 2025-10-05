# frozen_string_literal: true

module Qdc
  class ChapterMetadataFinder < Finder
    ALLOWED_METADATA_TYPES = %i[summaries suggestions].freeze

    attr_reader :chapter_id, :language_id

    def initialize(params = {})
      super(params)
      @chapter_id = validate_chapter_id
      @language_id = resolve_language_id
    end

    def chapter
      strong_memoize :chapter do
        Chapter.find_by(id: chapter_id) || raise_invalid_chapter
      end
    end

    def suggestions
      strong_memoize :suggestions do
        fetch_metadata(:suggestions, chapter_id)
      end
    end

    def next_chapter
      strong_memoize :next_chapter do
        return nil if chapter_id >= 114
        Chapter.find_by(id: chapter_id + 1)
      end
    end

    def previous_chapter
      strong_memoize :previous_chapter do
        return nil if chapter_id <= 1
        Chapter.find_by(id: chapter_id - 1)
      end
    end

    def next_chapter_summaries
      strong_memoize :next_chapter_summaries do
        return [] unless next_chapter
        fetch_metadata(:summaries, next_chapter.id)
      end
    end

    def previous_chapter_summaries
      strong_memoize :previous_chapter_summaries do
        return [] unless previous_chapter
        fetch_metadata(:summaries, previous_chapter.id)
      end
    end

    protected

    def fetch_metadata(type, chapter_id)
      raise ArgumentError, "Invalid metadata type: #{type}" unless ALLOWED_METADATA_TYPES.include?(type)

      default_language_id = Language.default&.id || 1

      ChapterMetadata
        .public_send(type)
        .active
        .for_chapter(chapter_id)
        .where(language_id: [language_id, default_language_id].uniq)
        .order(build_language_priority_case, :created_at)
    end

    def validate_chapter_id
      id = (params[:id] || params[:chapter_id]).to_i
      return id if id.between?(1, 114)
      raise_invalid_chapter
    end

    def resolve_language_id
      locale = params[:language].presence || params[:locale].presence || 'en'
      lang = Language.find_by(iso_code: locale)
      lang&.id || Language.default&.id || 1
    end

    def build_language_priority_case
      table = ChapterMetadata.arel_table
      language_id_value = language_id.to_i
      
      Arel::Nodes::Case.new
        .when(table[:language_id].eq(language_id_value))
        .then(0)
        .else(1)
    end

    def raise_invalid_chapter
      raise RestApi::RecordNotFound.new("Chapter ID must be between 1 and 114. Please select a valid chapter number.")
    end
  end
end
