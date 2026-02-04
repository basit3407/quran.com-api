# frozen_string_literal: true

module Api::Qdc
  class ChapterInfosController < Api::Qdc::ApiController
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

      # Check if resource_id parameter was provided (even if it doesn't resolve to a valid resource)
      resource_id_param = params[:resource_id]
      resource_requested = resource_id_param.present?

      # Filter by specific resource if requested and valid
      if resource_requested && resource_filter.present?
        query = query.where(resource_content_id: resource_filter)
      end

      # When resource_id is specified, don't fallback to default language - Only fallback when no specific resource is requested
      if resource_requested
        language = Language.find_with_id_or_iso_code(fetch_locale)

        # If resource_filter is nil (resource not found)
        return nil if resource_filter.nil? || language.nil?

        query.find_by(language_id: language.id)
      else
        # When no resource_id is specified, order by resource priority (highest first)
        language = Language.find_with_id_or_iso_code(fetch_locale)

        if language.nil? || language.default?
          query.joins(:resource_content).order('resource_contents.priority ASC').find_by(language_id: Language.default.id)
        else
          (query.joins(:resource_content).order('resource_contents.priority ASC').find_by(language_id: language.id) ||
           query.joins(:resource_content).order('resource_contents.priority ASC').find_by(language_id: Language.default.id))
        end
      end
    end

    def resources
      finder = ChapterFinder.new
      chapter = finder.find(params[:id])

      # Find language by ISO code to get the language_id, if not found, use default language
      language = Language.find_with_id_or_iso_code(fetch_locale) || Language.default

      # Build the query - strictly filter by language
      ResourceContent
        .allowed_to_share
        .approved
        .where(id: ChapterInfo.where(chapter_id: chapter.id).select(:resource_content_id))
        .where(language_id: language.id)
        .select('DISTINCT resource_contents.*')
        .order(priority: :asc)
        .includes(:translated_names)
    end

    def include_resources?
      params[:include_resources].to_s == 'true'
    end

    def resource_filter
      @resource_filter ||= begin
        resource_id = params[:resource_id]

        if resource_id.present?
          finder = ChapterFinder.new
          chapter = finder.find(params[:id])
          language = Language.find_with_id_or_iso_code(fetch_locale) || Language.default

          # Find the resource by ID or slug
          resource = if resource_id.to_s.match?(/^\d+$/)
            ResourceContent.find_by(id: resource_id.to_i)
          else
            ResourceContent.find_by(slug: resource_id)
          end

          # Only return the resource ID if it meets all security criteria:
          # 1. Resource exists
          # 2. It's approved
          # 3. It's allowed to share (not rejected)
          # 4. It has chapter_info for this specific chapter
          # 5. It belongs to the requested language
          if resource&.approved? &&
             !resource&.share_permission_is_rejected? &&
             ChapterInfo.where(chapter_id: chapter.id, resource_content_id: resource.id).exists? &&
             resource.language_id == language.id
            resource.id
          end
        end
      end
    end
  end
end
