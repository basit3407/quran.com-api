# frozen_string_literal: true

# == Schema Information
# Schema version: 20251218163500
#
# Table name: qiraat_reading_attributions
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  qiraat_reader_id      :bigint
#  qiraat_reading_id     :bigint           not null
#  qiraat_transmitter_id :bigint
#
# Indexes
#
#  index_qiraat_attributions_unique                            (qiraat_reading_id,qiraat_reader_id,qiraat_transmitter_id) UNIQUE
#  index_qiraat_reading_attributions_on_qiraat_reader_id       (qiraat_reader_id)
#  index_qiraat_reading_attributions_on_qiraat_reading_id      (qiraat_reading_id)
#  index_qiraat_reading_attributions_on_qiraat_transmitter_id  (qiraat_transmitter_id)
#
# Foreign Keys
#
#  fk_rails_1180d5b668  (qiraat_reading_id => qiraat_readings.id)
#  fk_rails_51fea9f850  (qiraat_reader_id => qiraat_readers.id)
#  fk_rails_559e46cb25  (qiraat_transmitter_id => qiraat_transmitters.id)
#

class QiraatReadingAttribution < ApplicationRecord
  # Associations
  belongs_to :qiraat_reading
  belongs_to :qiraat_reader, optional: true
  belongs_to :qiraat_transmitter, optional: true

  # Callbacks - auto-derive reader from transmitter before validation
  before_validation :derive_reader_from_transmitter

  # Validations
  validates :qiraat_reading_id, presence: true
  validates :qiraat_reading_id, uniqueness: {
    scope: [:qiraat_reader_id, :qiraat_transmitter_id],
    message: 'has already been attributed to this reader/transmitter combination'
  }
  validate :reader_or_transmitter_required
  validate :transmitter_belongs_to_reader, if: -> { qiraat_transmitter_id.present? && qiraat_reader_id.present? }

  # Scopes
  scope :for_reading, ->(reading_id) { where(qiraat_reading_id: reading_id) }
  scope :for_reader, ->(reader_id) { where(qiraat_reader_id: reader_id) }
  scope :for_transmitter, ->(transmitter_id) { where(qiraat_transmitter_id: transmitter_id) }
  scope :reader_level, -> { where(qiraat_transmitter_id: nil) }
  scope :transmitter_level, -> { where.not(qiraat_transmitter_id: nil) }
  scope :with_associations, -> { includes(:qiraat_reading, :qiraat_reader, :qiraat_transmitter) }

  # Delegations
  delegate :text_uthmani, :text_imlaei, :verse_key, to: :qiraat_reading
  delegate :name, :abbreviation, to: :qiraat_reader, prefix: true, allow_nil: true
  delegate :name, :abbreviation, to: :qiraat_transmitter, prefix: true, allow_nil: true

  # Instance methods
  def is_reader_level?
    qiraat_transmitter_id.nil?
  end

  def is_transmitter_level?
    !is_reader_level?
  end

  # Get the effective reader (either directly set or via transmitter)
  def effective_reader
    qiraat_reader || qiraat_transmitter&.qiraat_reader
  end

  def effective_reader_id
    qiraat_reader_id || qiraat_transmitter&.qiraat_reader_id
  end

  def display_attribution
    if is_reader_level?
      reader = effective_reader
      "#{reader&.name} (#{reader&.abbreviation})"
    else
      "#{effective_reader&.name} via #{qiraat_transmitter_name}"
    end
  end

  def full_attribution
    if is_reader_level?
      "#{qiraat_reading.text_uthmani} - #{effective_reader&.name} (all transmitters)"
    else
      "#{qiraat_reading.text_uthmani} - #{effective_reader&.name} via #{qiraat_transmitter_name}"
    end
  end

  def to_s
    display_attribution
  end

  private

  # Auto-derive reader from transmitter if not explicitly set
  def derive_reader_from_transmitter
    if qiraat_transmitter_id.present? && qiraat_reader_id.blank?
      self.qiraat_reader_id = qiraat_transmitter&.qiraat_reader_id
    end
  end

  # Ensure at least one of reader or transmitter is present
  def reader_or_transmitter_required
    if qiraat_reader_id.blank? && qiraat_transmitter_id.blank?
      errors.add(:base, 'At least one of reader or transmitter must be specified')
    end
  end

  def transmitter_belongs_to_reader
    return unless qiraat_transmitter.present? && qiraat_reader.present?

    unless qiraat_transmitter.qiraat_reader_id == qiraat_reader_id
      errors.add(
        :qiraat_transmitter_id,
        "transmitter #{qiraat_transmitter.name} does not belong to reader #{qiraat_reader.name}"
      )
    end
  end
end
