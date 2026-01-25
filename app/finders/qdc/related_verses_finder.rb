# frozen_string_literal: true

class Qdc::RelatedVersesFinder < Finder
  attr_reader :verse, :language

  def initialize(params)
    super(params)
    @language = Language.find_with_id_or_iso_code(params[:language] || 'en')
  end

  def find_verse
    strong_memoize :verse do
      @verse = Verse.find_by(verse_key: params[:verse_key])
      raise RestApi::RecordNotFound.new("Verse #{params[:verse_key]} not found") unless @verse
      @verse
    end
  end

  def load_related_verses
    @total_records = base_scope.count
    @results = base_scope.limit(per_page).offset((current_page - 1) * per_page)
  end

  def chapters
    strong_memoize :chapters do
      other_verse_ids = @results.map { |rv| rv.other_verse_for(find_verse.id).id }
      Chapter.for_related_verses(other_verse_ids, @language)
    end
  end

  private

  def base_scope
    strong_memoize :base_scope do
      RelatedVerse.related_to(find_verse, language: @language)
    end
  end
end