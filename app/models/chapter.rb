# frozen_string_literal: true

# == Schema Information
# Schema version: 20260104000003
#
# Table name: chapters
#
#  id                 :integer          not null, primary key
#  bismillah_pre      :boolean
#  chapter_number     :integer
#  hizbs_count        :integer
#  name_arabic        :string
#  name_complex       :string
#  name_simple        :string
#  pages              :string
#  revelation_order   :integer
#  revelation_place   :string
#  rub_el_hizbs_count :integer
#  rukus_count        :integer
#  verses_count       :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_chapters_on_chapter_number  (chapter_number)
#

class Chapter < ApplicationRecord
  include Slugable
  include QuranNavigationSearchable
  include NameTranslateable
  include NameTransliterateable

  has_many :verses
  has_many :chapter_infos
  has_many :chapter_metadata

  serialize :pages

  default_scope { order 'chapter_number asc' }

  # Load chapters with translated names for related verses display
  # @param verse_ids [Array<Integer>] IDs of the "other" verses in relationships
  # @param language [Language] The language for translated names
  # @return [Hash] Chapters indexed by id
  def self.for_related_verses(verse_ids, language = nil)
    return {} if verse_ids.blank?

    chapter_ids = Verse.where(id: verse_ids.uniq).pluck(:chapter_id).uniq
    return {} if chapter_ids.empty?

    language_ids = [language&.id, Language.default.id].compact.uniq
    language_order = if language
                  sanitize_sql_array([
                    "CASE WHEN translated_names.language_id = ? THEN 0 ELSE 1 END ASC",
                    language.id
                  ])
                else
                  'translated_names.language_priority DESC'
                end

    unscoped
      .where(id: chapter_ids)
      .where(translated_names: { language_id: language_ids })
      .order(Arel.sql(language_order))
      .includes(:translated_name)
      .index_by(&:id)
  end

  # Get the appropriate display name based on language
  # @param language [Language] The requested language
  # @return [String] The chapter name (Arabic for ar/ur, simple otherwise)
  def display_name_for(language)
    if language&.iso_code&.in?(%w[ar ur])
      name_arabic
    else
      name_simple
    end
  end
end