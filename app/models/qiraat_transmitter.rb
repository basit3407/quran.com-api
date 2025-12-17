# frozen_string_literal: true

# == Schema Information
# Schema version: 20251212185400
#
# Table name: qiraat_transmitters
#
#  id                   :bigint           not null, primary key
#  abbreviation         :string
#  death_year_gregorian :integer
#  death_year_hijri     :integer
#  is_primary           :boolean          default(FALSE)
#  name                 :string           not null
#  name_translations    :jsonb
#  position             :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  qiraat_reader_id     :bigint           not null
#
# Indexes
#
#  index_qiraat_transmitters_on_abbreviation         (abbreviation)
#  index_qiraat_transmitters_on_qiraat_reader_id     (qiraat_reader_id)
#  index_qiraat_transmitters_on_reader_and_position  (qiraat_reader_id,position)
#
# Foreign Keys
#
#  fk_rails_41778b477d  (qiraat_reader_id => qiraat_readers.id)
#

class QiraatTransmitter < ApplicationRecord
  # Associations
  belongs_to :qiraat_reader
  has_many :qiraat_reading_attributions, dependent: :destroy
  has_many :qiraat_readings, through: :qiraat_reading_attributions
  has_many :localized_contents, as: :resource, dependent: :destroy
  has_one :qirat_type

  # Validations
  validates :name, presence: true
  validates :abbreviation, presence: true, length: { maximum: 10 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :qiraat_reader_id, message: 'must be unique per reader' }
  validates :death_year_hijri, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :death_year_gregorian, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Validate only one primary transmitter per reader
  validate :only_one_primary_per_reader, if: :is_primary?

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :primary, -> { where(is_primary: true) }
  scope :for_reader, ->(reader_id) { where(qiraat_reader_id: reader_id) }
  scope :with_reader, -> { includes(:qiraat_reader) }

  # Callbacks
  before_validation :set_default_position, on: :create
  before_validation :normalize_abbreviation

  # Delegations
  delegate :name, :abbreviation, to: :qiraat_reader, prefix: true

  # Instance methods
  def translated_name_for(language)
    return name unless name_translations.present?

    language_code = language.is_a?(Language) ? language.iso_code : language.to_s
    name_translations[language_code] || name
  end

  def full_name
    "#{name} (#{abbreviation})"
  end

  def full_name_with_reader
    "#{name} via #{qiraat_reader.name}"
  end

  def death_year_display
    if death_year_hijri && death_year_gregorian
      "#{death_year_hijri} AH / #{death_year_gregorian} CE"
    elsif death_year_hijri
      "#{death_year_hijri} AH"
    elsif death_year_gregorian
      "#{death_year_gregorian} CE"
    else
      "Unknown"
    end
  end

  def bio_for(language)
    localized_contents.find_by(language: language, content_type: 'bio')
  end

  private

  def set_default_position
    return if position.present?

    max_position = self.class.where(qiraat_reader_id: qiraat_reader_id).maximum(:position) || 0
    self.position = max_position + 1
  end

  def normalize_abbreviation
    return unless abbreviation.present?

    self.abbreviation = abbreviation.strip
  end

  def only_one_primary_per_reader
    return unless qiraat_reader_id.present?

    existing_primary = QiraatTransmitter
      .where(qiraat_reader_id: qiraat_reader_id, is_primary: true)
      .where.not(id: id)
      .exists?

    if existing_primary
      errors.add(:is_primary, "reader #{qiraat_reader.name} already has a primary transmitter")
    end
  end
end
