# frozen_string_literal: true

# == Schema Information
# Schema version: 20260121105029
#
# Table name: qiraat_junctures
#
#  id          :bigint           not null, primary key
#  approved    :boolean          default(FALSE), not null
#  category    :string
#  flags       :string           default([]), is an Array
#  hizb_number :integer
#  juz_number  :integer
#  position    :integer          default(0)
#  text_simple :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_qiraat_junctures_on_approved     (approved)
#  index_qiraat_junctures_on_category     (category)
#  index_qiraat_junctures_on_hizb_number  (hizb_number)
#  index_qiraat_junctures_on_juz_number   (juz_number)
#

class QiraatJuncture < ApplicationRecord
  # Category classifications for junctures
  CATEGORIES = {
    'A' => 'meaning_difference',      # Tangible difference in meaning/translation
    'B' => 'orthographic_difference', # Words look different but mean the same
    'C' => 'phonetic_difference'      # Difference solely in pronunciation (future)
  }.freeze

  CATEGORY_LABELS = {
    'A' => 'Category A: Meaning Difference',
    'B' => 'Category B: Orthographic (Same Meaning)',
    'C' => 'Category C: Phonetic Only'
  }.freeze

  FLAGS = %w[
    grammatical
    phonetic
    morphological
    semantic
    dialectal
    orthographic
    recitation_style
  ].freeze

  # Associations
  has_many :qiraat_juncture_segments, dependent: :destroy
  has_many :qiraat_readings, dependent: :destroy
  has_many :localized_contents, as: :resource, dependent: :destroy

  accepts_nested_attributes_for :qiraat_juncture_segments, allow_destroy: true

  # Validations
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :category,
            inclusion: { in: CATEGORIES.keys, allow_blank: true }

  # Scopes
  scope :for_verse, ->(verse_id) {
    joins(:qiraat_juncture_segments)
      .where(qiraat_juncture_segments: { verse_id: verse_id })
      .distinct
      .order(:position)
  }
  scope :for_chapter, ->(chapter_id) {
    joins(qiraat_juncture_segments: :verse)
      .where(verses: { chapter_id: chapter_id })
      .distinct
  }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :with_category, -> { where.not(category: nil) }
  scope :without_category, -> { where(category: nil) }
  scope :with_readings, -> { includes(:qiraat_readings) }
  scope :with_segments, -> { includes(qiraat_juncture_segments: [:verse, :start_word, :end_word]) }
  scope :with_localized_content, -> { includes(:localized_contents) }
  scope :ordered, -> { order(:position) }
  scope :approved, -> { where(approved: true) }

  # Callbacks
  before_validation :set_default_position, on: :create

  # ============================================================
  # Segment-derived properties - ALL TEXT IS DERIVED, NOT STORED
  # ============================================================

  # Juncture text derived from all segments
  def juncture_text_uthmani
    segments = qiraat_juncture_segments.ordered
    return nil if segments.empty?

    segments.map(&:segment_text_uthmani).join(' ... ')
  end

  def juncture_text_imlaei
    segments = qiraat_juncture_segments.ordered
    return nil if segments.empty?

    segments.map(&:segment_text_imlaei).compact.join(' ... ')
  end

  def juncture_text_qpc_hafs
    segments = qiraat_juncture_segments.ordered
    return nil if segments.empty?

    segments.map(&:segment_text_qpc_hafs).compact.join(' ... ')
  end

  # Dynamic text field accessor - returns text based on field name
  # Supported fields: text_uthmani, text_imlaei, text_qpc_hafs
  def juncture_text(field = :text_uthmani)
    field_name = field.to_s.delete_prefix('text_')
    case field_name
    when 'uthmani'
      juncture_text_uthmani
    when 'imlaei'
      juncture_text_imlaei
    when 'qpc_hafs'
      juncture_text_qpc_hafs
    else
      juncture_text_uthmani
    end
  end

  # Primary verse (first segment's verse)
  def primary_verse
    qiraat_juncture_segments.ordered.first&.verse
  end

  # Word ID derived from first segment's start word
  def word_id
    qiraat_juncture_segments.ordered.first&.start_word_id
  end

  # Word position derived from first segment's start word
  def word_position
    qiraat_juncture_segments.ordered.first&.start_word&.position
  end

  # Effective start word position (from first segment)
  def effective_start_word_position
    qiraat_juncture_segments.ordered.first&.start_word&.position
  end

  # Effective end word position (from last segment)
  def effective_end_word_position
    qiraat_juncture_segments.ordered.last&.end_word&.position
  end

  # Verse key derived from segments
  def verse_key
    segments = qiraat_juncture_segments.ordered
    return nil if segments.empty?

    first_key = segments.first.verse_key
    last_key = segments.last.verse_key

    first_key == last_key ? first_key : "#{first_key}-#{last_key.split(':').last}"
  end

  # Full verse range for display (e.g., "8:65-66")
  def verse_range
    segments = qiraat_juncture_segments.ordered
    return nil if segments.empty?

    verse_keys = segments.map(&:verse_key).uniq

    if verse_keys.size == 1
      verse_keys.first
    else
      first = verse_keys.first
      last = verse_keys.last
      chapter = first.split(':').first
      first_verse = first.split(':').last
      last_verse = last.split(':').last
      "#{chapter}:#{first_verse}-#{last_verse}"
    end
  end

  # Does this juncture span multiple verses?
  def cross_verse?
    qiraat_juncture_segments.select(:verse_id).distinct.count > 1
  end

  # All Word objects across all segments
  def all_words
    qiraat_juncture_segments.ordered.flat_map(&:words)
  end

  # All verse IDs this juncture touches
  def verse_ids
    qiraat_juncture_segments.pluck(:verse_id).uniq
  end

  # Chapter ID (from primary verse)
  def chapter_id
    primary_verse&.chapter_id
  end

  # ============================================================
  # Content helpers
  # ============================================================

  def explanation_for(language)
    localized_contents.find_by(language: language, content_type: 'explanation')
  end

  def combined_translation_for(language)
    localized_contents.find_by(language: language, content_type: 'combined_translation')
  end

  # ============================================================
  # Flag management
  # ============================================================

  def add_flag(flag)
    return if flags.include?(flag)

    update(flags: flags + [flag])
  end

  def remove_flag(flag)
    update(flags: flags - [flag])
  end

  def has_flag?(flag)
    flags.include?(flag)
  end

  private

  def set_default_position
    return if position.present?

    max_position = self.class.maximum(:position) || 0
    self.position = max_position + 1
  end
end
