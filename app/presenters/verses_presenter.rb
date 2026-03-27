# frozen_string_literal: true

class VersesPresenter < BasePresenter
  attr_reader :mushaf_code,
              :verses_filter

  VERSE_FIELDS = [
    'chapter_id',
    'text_indopak',
    'text_imlaei_simple',
    'text_imlaei',
    'text_uthmani',
    'text_uthmani_simple',
    'text_uthmani_tajweed',
    'text_qpc_hafs',
    'qpc_uthmani_hafs', # TODO: deprecated and renamed to text_qpc_hafs
    'text_qpc_nastaleeq_hafs',
    'text_qpc_nastaleeq',
    'text_indopak_nastaleeq',
    'image_url',
    'image_width',
    'code_v1',
    'code_v2',
    'page_number',
    'v1_page',
    'v2_page'
  ]

  WORDS_FIELDS = [
    'verse_id',
    'chapter_id',
    'text_uthmani',
    'text_indopak',
    'text_imlaei_simple',
    'text_imlaei',
    'text_uthmani_simple',
    'text_uthmani_tajweed',
    'text_qpc_hafs',
    'verse_key',
    'location',
    'code_v1',
    'code_v2',
    'v1_page',
    'v2_page',
    'line_number',
    'line_v2',
    'line_v1'
  ]

  TRANSLATION_FIELDS = [
    'chapter_id',
    'verse_number',
    'verse_key',
    'juz_number',
    'hizb_number',
    'rub_el_hizb_number',
    'page_number',
    'resource_name',
    'language_name',
    'language_id',
    'id'
  ]

  TAFSIR_FIELDS = [
    'chapter_id',
    'verse_number',
    'verse_key',
    'juz_number',
    'hizb_number',
    'rub_el_hizb_number',
    'page_number',
    'group_verse_key_from',
    'group_verse_key_to',
    'group_tafsir_id',
    'start_verse_id',
    'end_verse_id',
    'resource_name',
    'language_name',
    'language_id',
    'id'
  ]

  def initialize(params, filter)
    super(params)

    @verses_filter = filter
    @finder = V4::VerseFinder.new(params)
  end

  def get_mushaf_code
    @mushaf_code || :v1
  end

  def random_verse
    filters = {
      chapter_id: params[:chapter_number],
      page_number: params[:page_number],
      juz_number: params[:juz_number],
      hizb_number: params[:hizb_number],
      rub_el_hizb_number: params[:rub_el_hizb_number]
    }.compact

    @finder.random_verse(
      filters,
      fetch_locale,
      tafsirs: fetch_tafsirs,
      translations: fetch_translations,
      audio: fetch_audio
    )
  end

  def find_verse
    case verses_filter
    when 'by_key'
      result = @finder.find_with_key(
        params[:verse_key],
        fetch_locale,
        words: render_words?,
        tafsirs: fetch_tafsirs,
        translations: fetch_translations,
        audio: fetch_audio
      )
      raise_404("Ayah not found") unless result

      result
    end
  end

  def verse_fields
    strong_memoize :fields do
      if (fields = params[:fields]).presence
        fields.split(',').select do |field|
          VERSE_FIELDS.include?(field)
        end
      else
        []
      end
    end
  end

  def word_fields
    strong_memoize :word_fields do
      if (fields = params[:word_fields]).presence
        fields = sanitize_query_fields(fields.split(','))
        detect_mushaf_code(fields)

        fields.select do |field|
          WORDS_FIELDS.include?(field)
        end
      else
        ['code_v1', 'page_number']
      end
    end
  end

  def translation_fields
    strong_memoize :translation_fields do
      if (fields = params[:translation_fields]).presence
        fields.split(',').select do |field|
          TRANSLATION_FIELDS.include?(field)
        end
      else
        []
      end
    end
  end

  def tafsir_fields
    strong_memoize :tafsir_fields do
      if (fields = params[:tafsir_fields]).presence
        fields.split(',').select do |field|
          TAFSIR_FIELDS.include?(field)
        end
      else
        []
      end
    end
  end

  def verses
    strong_memoize :verses do
      finder.load_verses(verses_filter,
                         fetch_locale,
                         mushaf: get_mushaf,
                         words: render_words?,
                         tafsirs: fetch_tafsirs,
                         translations: fetch_translations,
                         audio: fetch_audio)
    end
  end

  def mushaf_page_layout?
    verses_filter == 'by_page'
  end

  def verse_page_number_for(verse, page_layout: mushaf_page_layout?)
    if page_layout
      verse.get_page_number_for(mushaf: get_mushaf_id)
    else
      verse.get_qpc_page_number(get_mushaf_code)
    end
  end

  def verse_words_for(verse, page_layout: mushaf_page_layout?)
    if page_layout
      verse.mushaf_words.sort_by(&:position_in_verse)
    else
      verse.words
    end
  end

  def word_partial_locals(page_layout: mushaf_page_layout?)
    locals = { fields: word_fields }

    if page_layout
      locals[:page_layout] = true
    else
      locals[:mushaf_code] = get_mushaf_code
    end

    locals
  end

  def fetch_chapters
    chapters = Chapter.where(id: chapter_ids).includes(:translated_name)

    # Eager load translated names to avoid n+1 queries
    # Fallback to english translated names
    # if chapter don't have translated name for queried language
    with_default_names = chapters
                           .where(translated_names: { language_id: Language.default.id })

    chapters
      .where(translated_names: { language_id: language.id })
      .or(
        with_default_names
      )
      .order('translated_names.language_priority DESC')
  end

  def render_surah_detail?
    @lookahead.selects?('surah_detail')
  end

  def render_words?
    strong_memoize :words do
      @lookahead.selects?('words')
    end
  end

  def render_translations?
    strong_memoize :translations do
      @lookahead.selects?('translations') && fetch_translations.present?
    end
  end

  def render_audio?
    strong_memoize :auido do
      @lookahead.selects?('audio') && fetch_audio
    end
  end

  def render_tafsirs?
    strong_memoize :show_tafsir do
      @lookahead.selects?('tafsirs') && fetch_tafsirs.present?
    end
  end

  def single_verse_action?
    verses_filter == 'by_key'
  end

  # Related verses are only available for single verse endpoints (by_key)
  # This prevents unnecessary queries for multiple verse endpoints
  def render_related_verses?
    strong_memoize :render_related_verses do
      single_verse_action? && params[:related_verses].to_s == 'true'
    end
  end

  # Get related verses for a specific verse
  # @param verse [Verse] The verse to find relations for
  # @return [Array] Related verse records
  def related_verses_for(verse)
    @current_verse = verse
    @related_verses ||= RelatedVerse.related_to(verse, language: language).to_a
  end

  # Get chapters for related verses
  # @return [Hash] Chapters indexed by id
  def chapters_for_related_verses
    @related_chapters ||= begin
      return {} if @related_verses.blank?

      other_verse_ids = @related_verses.map { |rv| rv.other_verse_for(@current_verse.id).id }
      Chapter.for_related_verses(other_verse_ids, language)
    end
  end

  # Preload related verses lookup for a collection of verses
  # This should be called before iterating over verses to avoid N+1 queries
  # @param verses [Array<Verse>] The verses to preload for
  def preload_related_verses_lookup(verses)
    verse_ids = verses.map(&:id)
    
    # Get all verse IDs that have approved related verses in one query
    ids_with_relations = RelatedVerse
      .where(approved: true)
      .where('verse_id IN (?) OR related_verse_id IN (?)', verse_ids, verse_ids)
      .pluck(:verse_id, :related_verse_id)
      .flatten
      .uniq
    
    @related_verses_lookup = verse_ids.each_with_object({}) do |id, hash|
      hash[id] = ids_with_relations.include?(id)
    end
  end

  # Check if a verse has any related verses
  # Uses preloaded lookup if available, otherwise falls back to individual query
  # @param verse [Verse] The verse to check
  # @return [Boolean] True if the verse has related verses
  def has_related_verses?(verse)
    if @related_verses_lookup
      @related_verses_lookup[verse.id] || false
    else
      RelatedVerse.for_verse(verse.id).approved.exists?
    end
  end

  def get_language
    language
  end

  protected

  def chapter_ids
    verses.pluck(:chapter_id).uniq
  end

  def detect_mushaf_code(fields)
    if fields.include?('code_v2')
      @mushaf_code = :v2
    elsif fields.include?('text_uthmani')
      @mushaf_code = :uthmani
    elsif fields.include?('text_indopak')
      @mushaf_code = :indopak
    elsif fields.include?('text_imlaei_simple')
      @mushaf_code = :imlaei_simple
    elsif fields.include?('text_imlaei')
      @mushaf_code = :imlaei
    elsif fields.include?('text_uthmani_tajweed')
      @mushaf_code = :uthmani_tajweed
    elsif fields.include?('qpc_uthmani_hafs') || fields.include?('text_qpc_hafs')
      @mushaf_code = :text_qpc_hafs
    else
      @mushaf_code = :v1
    end
  end

  def fetch_tafsirs
    strong_memoize :approved_tafsirs do
      if params[:tafsirs]
        tafsirs = params[:tafsirs].to_s.split(',')
        approved_tafsirs = ResourceContent
                             .approved
                             .tafsirs
                             .verse_level
                             .allowed_to_share

        params[:tafsirs] = approved_tafsirs
                             .where(id: tafsirs)
                             .pluck(:id)

        params[:tafsirs]
      end
    end
  end

  def fetch_translations
    strong_memoize :approved_translations do
      if params[:translations]
        translations = params[:translations].to_s.split(',')

        approved_translations = ResourceContent
                                  .approved
                                  .translations
                                  .one_verse
                                  .allowed_to_share

        params[:translations] = approved_translations
                                  .where(id: translations)
                                  .or(approved_translations.where(slug: translations))
                                  .pluck(:id)
        params[:translations]
      end
    end
  end

  def fetch_audio
    strong_memoize :fetch_audio do
      if params[:audio] && params[:audio].to_i > 0
        Recitation.approved.find_by(id: params[:audio].to_i)&.id
      end
    end
  end
end
