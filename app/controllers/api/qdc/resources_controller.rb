# frozen_string_literal: true

module Api::Qdc
  class ResourcesController < ApiController
    def chapter_reciters
      @presenter = ::Audio::RecitationPresenter.new(params)
      render
    end

    def translations
      load_translations
      @locale = fetch_locale

      render
    end

    # TODO: deprecated, moved the filters to /resources/translations api
    def filter
      translation_ids = params[:translations].to_s.split(',')
      @translations = load_translations.where(id: translation_ids)
      @locale = fetch_locale
      render
    end

    def translation_info
      approved = ResourceContent
                   .includes(:short_descriptions)
                   .translations
                   .one_verse
                   .approved
                   .allowed_to_share

      @translation = find_resource(approved, params[:translation_id], true)

      if @translation
        @locale = fetch_locale
        render
      else
        render_404("Translation not found")
      end
    end

    def tafsirs
      list = ResourceContent
               .eager_load(:translated_name)
               .tafsirs
               .approved
               .order('priority ASC')

      @tafsirs = eager_load_translated_name(list)

      render
    end

    def word_by_word_translations
      list = ResourceContent.eager_load(:translated_name).approved.one_word.translations_only.order('priority ASC')

      @word_by_word_translations = eager_load_translated_name(list)

      render
    end

    def tafsir_info
      if @tafsir = fetch_tafsir_resource
        render
      else
        render_404("Tafsir not found")
      end
    end

    def recitations
      list = Recitation
               .eager_load(reciter: :translated_name)
               .approved
               .order('translated_names.language_priority desc')

      @recitations = eager_load_translated_name(list)

      render
    end

    def recitation_info
      @recitation = Recitation
                      .approved
                      .find_by(id: params[:recitation_id])

      # Load translated name
      resource = ResourceContent
                   .eager_load(:translated_name)
                   .where(id: @recitation&.resource_content_id)

      if @resource = eager_load_translated_name(resource).first
        render
      else
        render_404("Recitation not found")
      end
    end

    def recitation_styles
      render
    end

    def chapter_infos
      list = ResourceContent
               .eager_load(:translated_name)
               .chapter_info
               .one_chapter
               .approved

      @chapter_infos = eager_load_translated_name(list)

      render
    end

    def verse_media
      @media = ResourceContent
                 .includes(:language)
                 .media
                 .one_verse.approved

      render
    end

    def languages
      list = Language.with_translations.eager_load(:translated_name)
      @languages = eager_load_translated_name(list)

      render
    end

    def country_language_preference
      user_device_language = request.query_parameters[:user_device_language].presence
      country = request.query_parameters[:country].presence&.upcase

      # Require a valid user_device_language always
      if user_device_language.blank?
        return render_bad_request('user_device_language is required')
      end

      unless Language.exists?(iso_code: user_device_language)
        return render_bad_request('Invalid user_device_language')
      end

      # Validate country only if provided
      if country.present?
        valid_countries = ISO3166::Country.all.map(&:alpha2)
        unless valid_countries.include?(country)
          return render_bad_request('Invalid country code')
        end
      end

      if country.present?
        # First try to find country-specific preference
        preferences = CountryLanguagePreference.with_includes
                        .where(user_device_language: user_device_language, country: country)
        @preference = preferences.first

        # If no country-specific preference found, try global preference
        unless @preference
          @preference = CountryLanguagePreference.with_includes
                          .find_by(user_device_language: user_device_language, country: nil)
        end
      else
        # No country provided: search by user_device_language only
        # Prefer global (country: nil), then fall back to any match for that language
        @preference = CountryLanguagePreference.with_includes
                          .find_by(user_device_language: user_device_language, country: nil)

        unless @preference
          @preference = CountryLanguagePreference.with_includes
                            .where(user_device_language: user_device_language)
                            .first
        end
      end

      if @preference
        # Filter out unapproved resources when building the response
        @data = build_preference_data(@preference)
        render
      else
        render_404("No matching country language preference found")
      end
    end

    private

    def build_preference_data(preference)
      # Sanitize CSV IDs for default translations
      ids = if preference.default_translation_ids.present?
              preference.default_translation_ids
                .split(',')
                .map(&:strip)
                .reject(&:blank?)
                .map(&:to_i)
            else
              []
            end

      # QR specific default translations ids
      qr_ids = if preference.qr_default_translations_ids.present?
                 preference.qr_default_translations_ids
                   .split(',')
                   .map(&:strip)
                   .reject(&:blank?)
                   .map(&:to_i)
               else
                 []
               end

      {
        preference: preference,
        default_mushaf: preference.mushaf&.enabled ? preference.mushaf : nil,
        default_translations: ids.any? ?
          ResourceContent.where(id: ids).approved.includes(:translated_name) : [],
        qr_default_translations: qr_ids.any? ?
          ResourceContent.where(id: qr_ids).approved.includes(:translated_name) : [],
        default_tafsir: preference.tafsir&.approved? ? preference.tafsir : nil,
        default_wbw_language: preference.wbw_language,
        default_reciter: preference.reciter,
        ayah_reflections_languages: Language.where(iso_code: preference.ayah_reflections_languages&.split(',') || []),
        qr_reflection_languages: Language.where(iso_code: preference.qr_reflection_languages&.split(',') || []),
        learning_plan_languages: Language.where(iso_code: preference.learning_plan_languages&.split(',') || [])
      }
    end

    protected

    def load_translations
      list = ResourceContent
               .eager_load(:translated_name)
               .includes(:short_descriptions)
               .one_verse
               .translations
               .approved
               .order('priority ASC')

      if params[:ids].present? || params[:name].present?
        list = list.filter_by(ids: params[:ids], name: params[:name])
      end

      @translations = eager_load_translated_name(list)
    end
  end
end
