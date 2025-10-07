# frozen_string_literal: true

module Qdc
  class ChapterMetadataFinder < Finder
    DEFAULT_LANGUAGE_ID = 1
    MIN_CHAPTER_ID = 1
    MAX_CHAPTER_ID = 114

    attr_reader :chapter_id, :language_id, :default_language_id

    def initialize(params = {})
      super(params)
      @chapter_id = validate_chapter_id
      @language_id = resolve_language_id
      @default_language_id = Language.default&.id || DEFAULT_LANGUAGE_ID
    end

    def chapter
      @chapter ||= Chapter.find(chapter_id)
    end

    def suggestions
      metadata_for_chapter(chapter_id, :suggestions)
    end

    def next_chapter
      @next_chapter ||= find_adjacent_chapter(1)
    end

    def previous_chapter
      @previous_chapter ||= find_adjacent_chapter(-1)
    end

    def next_chapter_summaries
      adjacent_summaries(1)
    end

    def previous_chapter_summaries
      adjacent_summaries(-1)
    end

    private

    def adjacent_summaries(offset)
      adj = find_adjacent_chapter(offset)
      adj ? metadata_for_chapter(adj.id, :summaries) : []
    end

    def metadata_for_chapter(chapter_id, type)
      metadata_cache[chapter_id][type]
    end

    def metadata_cache
      @metadata_cache ||= build_metadata_cache
    end

    def build_metadata_cache
      grouped = Hash.new { |h, k| h[k] = { suggestions: [], summaries: [] } }

      fetch_all_metadata.group_by(&:chapter_id).each do |chapter_id, items|
        suggestions, summaries = items.partition { |m| m.metadata_type == 'suggestion' }
        grouped[chapter_id][:suggestions] = select_first_language_only(suggestions)
        grouped[chapter_id][:summaries] = select_first_language_only(summaries)
      end

      grouped
    end

    def fetch_all_metadata
      ChapterMetadata
        .includes(:language)
        .where(chapter_id: relevant_chapter_ids, language_id: prioritized_language_ids, is_active: true)
        .order(:chapter_id, language_priority_order, :created_at)
    end

    def relevant_chapter_ids
      [chapter_id,
       (chapter_id + 1 if chapter_id < MAX_CHAPTER_ID),
       (chapter_id - 1 if chapter_id > MIN_CHAPTER_ID)
      ].compact
    end

    def prioritized_language_ids
      @prioritized_language_ids ||= [language_id, default_language_id].uniq
    end

    def language_priority_order
      Arel.sql(
        ActiveRecord::Base.sanitize_sql_array(
          ["CASE WHEN language_id = ? THEN 0 ELSE 1 END", language_id]
        )
      )
    end

    def select_first_language_only(items)
      return [] if items.empty?
      first_lang_id = items.first.language_id
      items.select { |item| item.language_id == first_lang_id }
    end

    def find_adjacent_chapter(offset)
      new_id = chapter_id + offset
      return nil unless new_id.between?(MIN_CHAPTER_ID, MAX_CHAPTER_ID)
      Chapter.find_by(id: new_id)
    end

    def validate_chapter_id
      id_or_slug = (params[:id] || params[:chapter_id]).to_s.strip
      find_chapter(id_or_slug).id
    end

    def resolve_language_id
      locale = params[:language].presence || params[:locale].presence || 'en'
      lang = Language.find_by(iso_code: locale)
      lang&.id || Language.default&.id || DEFAULT_LANGUAGE_ID
    end
  end
end
