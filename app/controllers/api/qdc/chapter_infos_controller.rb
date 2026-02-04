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
      resource_id = params[:resource_id].presence
      language = resolved_language
      return nil if language.nil?

      if resource_id
        chapter_info_for_resource(resource_id, language)
      else
        # No resource_id specified - return highest priority resource for determined language
        chapter_info_scope
          .joins(:resource_content)
          .order('resource_contents.priority ASC')
          .find_by(language_id: language.id)
      end
    end

    def resources
      language = resolved_language
      return [] if language.nil?

      # Build the query for resources in the determined language
      ResourceContent
        .approved
        .where(id: chapter_info_scope.where(language_id: language.id).select(:resource_content_id))
        .where(language_id: language.id)
        .select('DISTINCT resource_contents.*')
        .order(priority: :asc)
        .includes(:translated_names)
    end

    def include_resources?
      params[:include_resources].to_s == 'true'
    end

    def resource_filter
      # This method is kept for backward compatibility but delegates to chapter_info_for_resource
      @resource_filter ||= begin
        resource_id = params[:resource_id].presence
        if resource_id.present?
          language = resolved_language

          if language
            chapter_info_for_resource(resource_id, language)&.resource_content_id
          end
        end
      end
    end

    def chapter
      @chapter ||= ChapterFinder.new.find(params[:id])
    end

    def chapter_info_scope
      @chapter_info_scope ||= ChapterInfo.where(chapter_id: chapter.id)
    end

    def language_param_present?
      params[:language].present? || params[:locale].present?
    end

    def requested_language
      return nil unless language_param_present?

      @requested_language ||= Language.find_with_id_or_iso_code(fetch_locale)
    end

    def default_language
      @default_language ||= Language.default
    end

    def resolved_language
      return @resolved_language if defined?(@resolved_language)

      language = requested_language || default_language

      if language_param_present?
        if language_has_resources?(language)
          @resolved_language = language
        elsif no_fallback_language?(language)
          @resolved_language = nil
        else
          @resolved_language = default_language
        end
      else
        @resolved_language = language
      end
    end

    def no_fallback_language?(language)
      language.iso_code == 'ar' || language.iso_code == 'en'
    end

    def language_has_resources?(language)
      return false if language.nil?

      @language_has_resources ||= {}
      @language_has_resources[language.id] = chapter_info_scope.where(language_id: language.id).exists? unless @language_has_resources.key?(language.id)
      @language_has_resources[language.id]
    end

    # Find chapter_info by resource ID or slug within a specific language context
    def chapter_info_for_resource(resource_id, language)
      id_or_slug_filter = if resource_id.to_s.match?(/^\d+$/)
        { id: resource_id.to_i }
      else
        { slug: resource_id }
      end

      chapter_info_scope
        .where(language_id: language.id)
        .joins(:resource_content)
        .merge(ResourceContent.approved.where(language_id: language.id))
        .find_by(resource_contents: id_or_slug_filter)
    end
  end
end
