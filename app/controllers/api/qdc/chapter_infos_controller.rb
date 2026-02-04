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

      # Check if resource_id parameter was provided
      resource_id_param = params[:resource_id]
      resource_requested = resource_id_param.present?

      # Determine the requested language
      requested_language = Language.find_with_id_or_iso_code(fetch_locale)

      # Base case: if no language specified, fallback to default (en)
      target_language = requested_language || Language.default

      # CRITICAL: Check if the target language has ANY chapter_info resources at all
      language_has_resources = query.where(language_id: target_language.id).exists?

      if !language_has_resources && requested_language
        # Language doesn't have any chapter_info resources
        # If language is 'ar' or 'en', return null (don't fallback)
        if target_language.iso_code == 'ar' || target_language.iso_code == 'en'
          return nil
        else
          # For all other languages, fallback the entire context to 'en'
          target_language = Language.default
        end
      end

      # Now apply resource_id filter within the determined language context
      if resource_requested
        # Find the resource within the target language context
        resource = find_resource_in_language(resource_id_param, chapter, target_language)

        # If resource not found in the target language, return null
        return nil if resource.nil?

        # Return chapter_info for the specific resource and determined language
        query.find_by(language_id: target_language.id, resource_content_id: resource.id)
      else
        # No resource_id specified - return highest priority resource for determined language
        query.joins(:resource_content)
             .order('resource_contents.priority ASC')
             .find_by(language_id: target_language.id)
      end
    end

    def resources
      finder = ChapterFinder.new
      chapter = finder.find(params[:id])

      # Determine the requested language
      requested_language = Language.find_with_id_or_iso_code(fetch_locale)

      # Base case: if no language specified, fallback to default (en)
      target_language = requested_language || Language.default

      # CRITICAL: Check if the target language has ANY chapter_info resources at all
      language_has_resources = ChapterInfo.where(chapter_id: chapter.id, language_id: target_language.id).exists?

      if !language_has_resources && requested_language
        # Language doesn't have any chapter_info resources
        # If language is 'ar' or 'en', return empty (don't fallback)
        if target_language.iso_code == 'ar' || target_language.iso_code == 'en'
          return []
        else
          # For all other languages, fallback the entire context to 'en'
          target_language = Language.default
        end
      end

      # Build the query for resources in the determined language
      ResourceContent
        .allowed_to_share
        .approved
        .where(id: ChapterInfo.where(chapter_id: chapter.id).select(:resource_content_id))
        .where(language_id: target_language.id)
        .select('DISTINCT resource_contents.*')
        .order(priority: :asc)
        .includes(:translated_names)
    end

    def include_resources?
      params[:include_resources].to_s == 'true'
    end

    # Find a resource by ID or slug within a specific language context
    def find_resource_in_language(resource_id, chapter, target_language)
      # Find the resource by ID or slug
      resource = if resource_id.to_s.match?(/^\d+$/)
        ResourceContent.find_by(id: resource_id.to_i)
      else
        ResourceContent.find_by(slug: resource_id)
      end

      # Only return the resource if it meets all security criteria:
      # 1. Resource exists
      # 2. It's approved
      # 3. It's allowed to share (not rejected)
      # 4. It has chapter_info for this specific chapter
      # 5. It belongs to the target language
      if resource&.approved? &&
         !resource&.share_permission_is_rejected? &&
         ChapterInfo.where(chapter_id: chapter.id, resource_content_id: resource.id).exists? &&
         resource.language_id == target_language.id
        resource
      else
        nil
      end
    end

    def resource_filter
      # This method is kept for backward compatibility but delegates to find_resource_in_language
      @resource_filter ||= begin
        resource_id = params[:resource_id]

        if resource_id.present?
          finder = ChapterFinder.new
          chapter = finder.find(params[:id])
          requested_language = Language.find_with_id_or_iso_code(fetch_locale)

          # Determine the target language (with fallback logic)
          target_language = requested_language || Language.default

          # Check if language has resources
          language_has_resources = ChapterInfo.where(chapter_id: chapter.id, language_id: target_language.id).exists?

          if !language_has_resources && requested_language
            if target_language.iso_code != 'ar' && target_language.iso_code != 'en'
              target_language = Language.default
            end
          end

          resource = find_resource_in_language(resource_id, chapter, target_language)
          resource&.id
        end
      end
    end
  end
end
