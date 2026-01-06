# frozen_string_literal: true

class VerseFinder < Finder
  def find(verse_key, language_code = 'en')
    unless verse_key.include?(':')
      verse_key = "#{chapter.id}:#{verse_key}"
    end

    @results = Verse.where(chapter_id: chapter.id)

    load_verses(language_code).find_with_id_or_key(verse_key) || raise_invalid_ayah_number
  end

  def random_verse(filters, language_code, words: true, tafsirs: false, translations: false, reciter: false)
    @results = Verse.unscope(:order).where(filters).order('RANDOM()').limit(3)

    load_translations
    load_words(language_code)
    load_audio
    translations_order = params[:translations].present? ? ',translations.priority ASC' : ''

    @results.order("verses.verse_index ASC, words.position ASC, word_translations.priority ASC #{translations_order}".strip)
            .sample
  end

  def load_verses(language_code)
    fetch_verses_range
    load_translations
    load_words(language_code)
    load_audio
    translations_order = params[:translations].present? ? ',translations.priority ASC' : ''

    @results.order("verses.verse_index ASC, words.position ASC, word_translations.priority ASC #{translations_order}".strip)
  end

  def total_records
    @total_records || total_verses
  end

  protected
  def fetch_verses_range
    return @results if @results

    verse_start = verse_pagination_start
    verse_end = verse_pagination_end(verse_start)

    @results = Verse
                 .where(chapter_id: chapter.id)
                 .where('verses.verse_number >= ? AND verses.verse_number <= ?', verse_start.to_i, verse_end.to_i)
  end

  def load_words(word_translation_lang)
    language = Language.find_with_id_or_iso_code(word_translation_lang)

    approved_word_by_word_translations = ResourceContent.approved.one_word.translations_only.allowed_to_share
    words_with_default_translation = results.where(word_translations: { language_id: Language.default.id, resource_content_id: approved_word_by_word_translations })

    if language
      @results = @results
                   .where(word_translations: { language_id: language.id, resource_content_id: approved_word_by_word_translations })
                   .or(words_with_default_translation)
                   .eager_load(words: eager_load_words)
    else
      @results = words_with_default_translation
                   .eager_load(words: eager_load_words)
    end
  end

  def load_translations
    translations = params[:translations]

    if translations.present?
      @results = @results
                   .where(translations: { resource_content_id: translations })
                   .eager_load(:translations)
    end
  end

  def load_audio
    if params[:recitation].present?
      @results = @results
                   .where(audio_files: { recitation_id: params[:recitation] })
                   .eager_load(:audio_file)
    end
  end

  def set_offset
    if offset.present?
      @results = @results.offset(offset)
    end
  end

  def offset
    params[:offset] ? params[:offset].to_i.abs : nil
  end

  def eager_load_words
    :word_translation
  end

  def verse_pagination_start
    start = 1 + (current_page - 1) * per_page
    start = min(start, total_verses)
    if offset
      min(start + offset, total_verses)
    else
      start
    end
  end

  def verse_pagination_end(start)
    if params[:id]
      # for show page, skip the pagination
      min(params[:id].to_i, chapter.verses_count)
    else
      min((start + per_page) - 1, chapter.verses_count)
    end
  end

  def chapter
    strong_memoize :chapter do
      find_chapter
    end
  end

  def expand_n_ayah_tafsirs(records, tafsir_resource_ids)
    normalized_ids = normalize_resource_ids(tafsir_resource_ids)
    return records if normalized_ids.empty?

    n_ayah_ids = ResourceContent.n_verse.where(id: normalized_ids).pluck(:id)
    return records if n_ayah_ids.empty?

    verses = Array(records).compact
    return records if verses.empty?

    verse_ids = verses.map(&:id)
    min_id = verse_ids.min
    max_id = verse_ids.max
    group_texts = {}

    verses.each do |verse|
      association = verse.association(:tafsirs)
      association.loaded! unless association.loaded?
      association.target ||= []

      association.target.each do |tafsir|
        next unless n_ayah_ids.include?(tafsir.resource_content_id)

        key = tafsir_group_key(tafsir)
        next unless key

        group_texts[key] ||= tafsir.text if tafsir.text.present?
      end
    end

    range_tafsirs = Tafsir
                      .where(resource_content_id: n_ayah_ids)
                      .where.not(start_verse_id: nil, end_verse_id: nil)
                      .where('start_verse_id <= ? AND end_verse_id >= ?', max_id, min_id)

    range_tafsirs.each do |tafsir|
      key = tafsir_group_key(tafsir)
      next unless key

      group_texts[key] ||= tafsir.text if tafsir.text.present?
    end

    existing_keys_by_verse = {}

    verses.each do |verse|
      existing_keys = {}

      verse.tafsirs.each do |tafsir|
        next unless n_ayah_ids.include?(tafsir.resource_content_id)

        key = tafsir_group_key(tafsir)
        existing_keys[key] = true if key

        if tafsir.text.blank?
          group_text = group_texts[key]
          tafsir.text = group_text if group_text.present?
        end
      end

      existing_keys_by_verse[verse.id] = existing_keys
    end

    range_tafsirs.each do |tafsir|
      key = tafsir_group_key(tafsir)
      next unless key

      if tafsir.text.blank?
        group_text = group_texts[key]
        tafsir.text = group_text if group_text.present?
      end

      verses.each do |verse|
        next unless verse.id.between?(tafsir.start_verse_id, tafsir.end_verse_id)

        existing_keys = existing_keys_by_verse[verse.id]
        next if existing_keys[key]

        verse.association(:tafsirs).target << tafsir
        existing_keys[key] = true
      end
    end

    records
  end

  def normalize_resource_ids(resource_ids)
    return [] if resource_ids.blank?

    Array(resource_ids)
      .flat_map { |value| value.to_s.split(',') }
      .map(&:to_i)
      .uniq
  end

  def tafsir_group_key(tafsir)
    if tafsir.group_tafsir_id.present?
      [:group, tafsir.resource_content_id, tafsir.group_tafsir_id]
    elsif tafsir.start_verse_id.present? && tafsir.end_verse_id.present?
      [:range, tafsir.resource_content_id, tafsir.start_verse_id, tafsir.end_verse_id]
    end
  end
end
