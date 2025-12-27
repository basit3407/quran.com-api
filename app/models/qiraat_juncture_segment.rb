# frozen_string_literal: true

# == Schema Information
# Schema version: 20251216192523
#
# Table name: qiraat_juncture_segments
#
#  id                 :bigint           not null, primary key
#  position           :integer          default(0), not null
#  verse_key          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  end_word_id        :bigint           not null
#  qiraat_juncture_id :bigint           not null
#  start_word_id      :bigint           not null
#  verse_id           :bigint           not null
#
# Indexes
#
#  idx_juncture_segments_on_juncture_position            (qiraat_juncture_id,position)
#  index_qiraat_juncture_segments_on_end_word_id         (end_word_id)
#  index_qiraat_juncture_segments_on_qiraat_juncture_id  (qiraat_juncture_id)
#  index_qiraat_juncture_segments_on_start_word_id       (start_word_id)
#  index_qiraat_juncture_segments_on_verse_id            (verse_id)
#
# Foreign Keys
#
#  fk_rails_5ede9ba400  (end_word_id => words.id)
#  fk_rails_8d12243c8f  (qiraat_juncture_id => qiraat_junctures.id)
#  fk_rails_9bc1f8c01c  (start_word_id => words.id)
#  fk_rails_ab72bbf9d8  (verse_id => verses.id)
#

class QiraatJunctureSegment < ApplicationRecord
  # Associations
  belongs_to :qiraat_juncture
  belongs_to :verse
  belongs_to :start_word, class_name: 'Word'
  belongs_to :end_word, class_name: 'Word'

  # Validations
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :words_belong_to_same_verse
  validate :end_word_after_start_word

  # Scopes
  scope :ordered, -> { order(:position) }

  # Callbacks
  before_validation :set_verse_key

  # Instance methods

  # Returns all Word objects in this segment (from start to end)
  def words
    return [] unless start_word && end_word

    Word.where(verse_id: verse_id)
        .where(position: start_word.position..end_word.position)
        .order(:position)
  end

  # Derived text from words - NOT stored in DB
  def segment_text_uthmani
    words.pluck(:text_uthmani).join(' ')
  end

  def segment_text_imlaei
    words.pluck(:text_imlaei).compact.join(' ')
  end

  def segment_text_qpc_hafs
    words.pluck(:text_qpc_hafs).compact.join(' ')
  end

  # Dynamic text field accessor - returns text based on field name
  # Supported fields: text_uthmani, text_imlaei, text_qpc_hafs
  def segment_text(field = :text_uthmani)
    field_name = field.to_s.delete_prefix('text_')
    case field_name
    when 'uthmani'
      segment_text_uthmani
    when 'imlaei'
      segment_text_imlaei
    when 'qpc_hafs'
      segment_text_qpc_hafs
    else
      segment_text_uthmani
    end
  end

  # Word positions (for display/convenience)
  def start_word_position
    start_word&.position
  end

  def end_word_position
    end_word&.position
  end

  # Is this a single-word segment?
  def single_word?
    start_word_id == end_word_id
  end

  # Word count in this segment
  def word_count
    return 0 unless start_word && end_word

    (end_word.position - start_word.position) + 1
  end

  private

  def words_belong_to_same_verse
    return unless start_word && end_word && verse

    unless start_word.verse_id == verse_id
      errors.add(:start_word, 'must belong to the segment verse')
    end

    unless end_word.verse_id == verse_id
      errors.add(:end_word, 'must belong to the segment verse')
    end
  end

  def end_word_after_start_word
    return unless start_word && end_word

    if end_word.position < start_word.position
      errors.add(:end_word, 'must be at or after start_word')
    end
  end

  def set_verse_key
    self.verse_key = verse&.verse_key
  end
end
