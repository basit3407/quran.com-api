# frozen_string_literal: true

# == Schema Information
# Schema version: 20251218163500
#
# Table name: qiraat_readers
#
#  id                   :bigint           not null, primary key
#  abbreviation         :string           not null
#  death_year_gregorian :integer
#  death_year_hijri     :integer
#  name                 :string           not null
#  name_translations    :jsonb
#  position             :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_qiraat_readers_on_abbreviation  (abbreviation) UNIQUE
#  index_qiraat_readers_on_position      (position)
#

class QiraatReader < ApplicationRecord
  # Associations
  has_many :qiraat_transmitters, dependent: :destroy
  has_many :qiraat_reading_attributions, dependent: :destroy
  has_many :qiraat_readings, through: :qiraat_reading_attributions
  has_many :localized_contents, as: :resource, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :position, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  validates :death_year_hijri, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :death_year_gregorian, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :with_transmitters, -> { includes(:qiraat_transmitters) }
  scope :with_localized_content, -> { includes(:localized_contents) }

  # Callbacks
  before_validation :set_default_position, on: :create
  before_validation :normalize_abbreviation

  # Class methods
  def self.canonical_ten
    ordered.limit(10)
  end

  # Instance methods
  def primary_transmitter
    qiraat_transmitters.find_by(is_primary: true)
  end

  def bio_for(language)
    localized_contents.find_by(language: language, content_type: 'bio')
  end

  def translated_name_for(language)
    return name unless name_translations.present?

    language_code = language.is_a?(Language) ? language.iso_code : language.to_s
    name_translations[language_code] || name
  end

  def full_name
    "#{name} (#{abbreviation})"
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

  private

  def set_default_position
    return if position.present?

    max_position = self.class.maximum(:position) || 0
    self.position = max_position + 1
  end

  def normalize_abbreviation
    return unless abbreviation.present?

    self.abbreviation = abbreviation.strip
  end
end
