# frozen_string_literal: true

module Api::Qdc
  class ChapterInfosController < Api::V3::ChapterInfosController
    # GET /api/qdc/chapters/1/info
    def show
      @chapter_info = chapter_info
      @resources = resources if include_resources?
      render
    end

    protected

    def chapter_info
      finder = ChapterFinder.new
      chapter = finder.find(params[:id])

      query = ChapterInfo.where(chapter_id: chapter.id)

      # Filter by specific resource if requested
      if resource_filter.present?
        query = query.where(resource_content_id: resource_filter)
      end

      query.filter_by_language_or_default(fetch_locale)
    end

    def resources
      finder = ChapterFinder.new
      chapter = finder.find(params[:id])

      # Find language by ISO code to get the language_id
      # If not found or not provided, use default language
      language = Language.find_with_id_or_iso_code(fetch_locale) || Language.default

      # Build the query - strictly filter by language (no fallback for resources)
      ResourceContent
        .allowed_to_share
        .where(id: ChapterInfo.where(chapter_id: chapter.id).select(:resource_content_id))
        .where(language_id: language.id)
        .select('DISTINCT resource_contents.*')
        .includes(:translated_names)
    end

    def include_resources?
      params[:include_resources].to_s == 'true'
    end

    def resource_filter
      @resource_filter ||= begin
        resource_id = params[:resource_id]

        if resource_id.present?
          if resource_id.to_s.match?(/^\d+$/)
            resource_id.to_i
          else
            resource = ResourceContent.find_by(slug: resource_id)
            resource&.id
          end
        end
      end
    end
  end
end
