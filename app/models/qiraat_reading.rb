# frozen_string_literal: true

# == Schema Information
# Schema version: 20251218163500
#
# Table name: qiraat_readings
#
#  id                 :bigint           not null, primary key
#  color              :string           default("#f5f5f5")
#  grammatical_form   :string
#  position           :integer          default(0)
#  root_letters       :string
#  text_imlaei        :string
#  text_uthmani       :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  qiraat_juncture_id :bigint           not null
#
# Indexes
#
#  index_qiraat_readings_on_juncture_and_position  (qiraat_juncture_id,position)
#  index_qiraat_readings_on_qiraat_juncture_id     (qiraat_juncture_id)
#
# Foreign Keys
#
#  fk_rails_3356342a29  (qiraat_juncture_id => qiraat_junctures.id)
#

class QiraatReading < ApplicationRecord
  # Associations
  belongs_to :qiraat_juncture
  has_many :qiraat_reading_attributions, dependent: :destroy
  has_many :qiraat_readers, through: :qiraat_reading_attributions
  has_many :qiraat_transmitters, through: :qiraat_reading_attributions
  has_many :localized_contents, as: :resource, dependent: :destroy

  # Shared explanations (N:M via memberships)
  has_many :qiraat_reading_explanation_memberships, dependent: :destroy
  has_many :qiraat_reading_explanations, through: :qiraat_reading_explanation_memberships

  # Shared translations (N:M via memberships) - same pattern as explanations
  has_many :qiraat_reading_translation_memberships, dependent: :destroy
  has_many :qiraat_reading_translations, through: :qiraat_reading_translation_memberships

  # Validations
  validates :text_uthmani, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :qiraat_juncture_id, message: 'must be unique per juncture' }
  validates :root_letters, format: { with: /\A[\p{Arabic}\s]+\z/, message: 'must contain only Arabic letters' }, allow_blank: true

  scope :ordered, -> { order(:position) }
  scope :for_juncture, ->(juncture_id) { where(qiraat_juncture_id: juncture_id) }
  scope :with_attributions, -> { includes(:qiraat_reading_attributions) }
  scope :with_readers, -> { includes(qiraat_reading_attributions: :qiraat_reader) }
  scope :with_localized_content, -> { includes(:localized_contents) }
  scope :with_explanations, -> { includes(qiraat_reading_explanations: :localized_contents) }
  scope :with_translations, -> { includes(qiraat_reading_translations: :localized_contents) }

  # Callbacks
  before_validation :set_default_position, on: :create
  before_save :set_default_imlaei

  # Delegations
  delegate :verse, :verse_key, to: :qiraat_juncture

  # Instance methods
  # Get translation from shared translation entities first, then fallback to direct localized_contents
  # Includes English fallback if content not available in requested language
  def translation_for(language)
    # First check shared translations (new pattern)
    shared_translation = qiraat_reading_translations.ordered.first&.translation_text_for_with_fallback(language)
    return shared_translation if shared_translation.present?

    # Fallback to direct localized_contents (legacy/simple case)
    content = localized_contents.find_by(language: language, content_type: 'translation')&.text
    return content if content.present?

    # Fallback to English if requested language is not English
    return nil if language.iso_code == 'en'
    english = Language.find_by(iso_code: 'en')
    return nil unless english
    localized_contents.find_by(language: english, content_type: 'translation')&.text
  end

  def transliteration_for(language)
    # Try requested language first
    content = localized_contents.find_by(language: language, content_type: 'transliteration')&.text
    return content if content.present?

    # Fallback to English
    return nil if language.iso_code == 'en'
    english = Language.find_by(iso_code: 'en')
    return nil unless english
    localized_contents.find_by(language: english, content_type: 'transliteration')&.text
  end

  # Get translations from shared translation entities
  # Returns an array of translation hashes (since multiple translations can be shared)
  # Includes English fallback
  # Get translations from shared translation entities
  # Returns an array of translation hashes (since multiple translations can be shared)
  # Includes English fallback ONLY if no translations in the requested language are found.
  # This prevents showing both Arabic and English versions of the same reading if they are stored as separate entities.
  def translations_for(language)
    # 1. Try to find exact matches in the requested language
    exact_matches = qiraat_reading_translations.ordered.filter_map do |translation|
      translation.translation_for(language)
    end

    return exact_matches if exact_matches.present?

    # 2. Fallback to English if requested language is not English
    return [] if language.iso_code == 'en'

    english = Language.find_by(iso_code: 'en')
    return [] unless english

    qiraat_reading_translations.ordered.filter_map do |translation|
      translation.translation_for(english)
    end
  end

  # Get explanations from shared explanation entities
  # Returns an array of explanation hashes (since multiple explanations can be shared)
  # Includes English fallback
  def explanations_for(language)
    qiraat_reading_explanations.ordered.filter_map do |explanation|
      explanation.explanation_for_with_fallback(language)
    end
  end

  # Returns first explanation (for convenience)
  # Includes English fallback
  def explanation_for(language)
    qiraat_reading_explanations.ordered.first&.explanation_for_with_fallback(language)
  end

  # Add an explanation to this reading
  def add_explanation(explanation)
    qiraat_reading_explanation_memberships.find_or_create_by!(qiraat_reading_explanation: explanation)
  end

  # Remove an explanation from this reading
  def remove_explanation(explanation)
    qiraat_reading_explanation_memberships.find_by(qiraat_reading_explanation: explanation)&.destroy
  end

  # Add a translation to this reading
  def add_translation(translation)
    qiraat_reading_translation_memberships.find_or_create_by!(qiraat_reading_translation: translation)
  end

  # Remove a translation from this reading
  def remove_translation(translation)
    qiraat_reading_translation_memberships.find_by(qiraat_reading_translation: translation)&.destroy
  end

  def attributed_to?(reader_or_transmitter)
    case reader_or_transmitter
    when QiraatReader
      qiraat_readers.include?(reader_or_transmitter)
    when QiraatTransmitter
      qiraat_transmitters.include?(reader_or_transmitter)
    else
      false
    end
  end

  def readers_list
    qiraat_reading_attributions.includes(:qiraat_reader).map do |attr|
      if attr.qiraat_transmitter_id.nil?
        "#{attr.qiraat_reader.name} (all transmitters)"
      else
        "#{attr.qiraat_reader.name} via #{attr.qiraat_transmitter.name}"
      end
    end
  end

  def primary_readers
    qiraat_reading_attributions
      .where(qiraat_transmitter_id: nil)
      .includes(:qiraat_reader)
      .map(&:qiraat_reader)
  end

  def specific_transmitters
    qiraat_reading_attributions
      .where.not(qiraat_transmitter_id: nil)
      .includes(:qiraat_transmitter)
      .map(&:qiraat_transmitter)
  end

  def add_reader(reader, transmitter: nil)
    qiraat_reading_attributions.find_or_create_by!(
      qiraat_reader: reader,
      qiraat_transmitter: transmitter
    )
  end

  def remove_reader(reader, transmitter: nil)
    attribution = qiraat_reading_attributions.find_by(
      qiraat_reader: reader,
      qiraat_transmitter: transmitter
    )
    attribution&.destroy
  end

  private

  def set_default_position
    return if position.present?

    max_position = self.class.where(qiraat_juncture_id: qiraat_juncture_id).maximum(:position) || 0
    self.position = max_position + 1
  end

  def set_default_imlaei
    return if text_imlaei.present?

    self.text_imlaei = text_uthmani
  end
end
