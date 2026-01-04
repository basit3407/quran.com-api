# frozen_string_literal: true

# == Schema Information
# Schema version: 20251212185400
#
# Table name: localized_contents
#
#  id                  :bigint           not null, primary key
#  content_type        :string           not null
#  language_name       :string
#  metadata            :jsonb
#  position            :integer          default(0)
#  resource_type       :string           not null
#  short_text          :text
#  source              :string
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :bigint           not null
#  resource_content_id :bigint
#  resource_id         :bigint           not null
#
# Indexes
#
#  index_localized_contents_on_content_type           (content_type)
#  index_localized_contents_on_language_id            (language_id)
#  index_localized_contents_on_resource               (resource_type,resource_id)
#  index_localized_contents_on_resource_and_language  (resource_type,resource_id,language_id)
#  index_localized_contents_on_resource_content_id    (resource_content_id)
#  index_localized_contents_on_resource_lang_type     (resource_type,resource_id,language_id,content_type)
#  index_localized_contents_unique                    (resource_type,resource_id,language_id,content_type,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_5e6f46b08d  (language_id => languages.id)
#  fk_rails_fabeb78378  (resource_content_id => resource_contents.id)
#

class LocalizedContent < ApplicationRecord
  # Polymorphic association - can belong to any model
  belongs_to :resource, polymorphic: true
  belongs_to :language

  # Validations
  validates :content_type, presence: true
  validates :content_type, inclusion: {
    in: %w[bio name translation transliteration explanation combined_translation notes],
    message: '%{value} is not a valid content type'
  }
  validates :text, presence: true, if: -> { short_text.blank? }
  validates :resource_type, :resource_id, :language_id, presence: true

  # Unique constraint enforced at DB level but also validate here
  validates :content_type, uniqueness: {
    scope: [:resource_type, :resource_id, :language_id],
    message: 'already exists for this resource, language, and content type'
  }

  # Scopes
  scope :for_language, ->(language) { where(language: language) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :bios, -> { where(content_type: 'bio') }
  scope :names, -> { where(content_type: 'name') }
  scope :translations, -> { where(content_type: 'translation') }
  scope :transliterations, -> { where(content_type: 'transliteration') }
  scope :explanations, -> { where(content_type: 'explanation') }
  scope :with_source, -> { where.not(source: nil) }

  # Store accessor for metadata JSONB field
  store_accessor :metadata, :author, :verified, :reviewed_by, :notes

  # Class methods
  def self.content_types
    %w[bio name translation transliteration explanation combined_translation notes]
  end

  # Valid resource types for polymorphic association
  def self.valid_resource_types
    %w[QiraatReader QiraatTransmitter QiraatReading QiraatReadingExplanation QiraatJuncture Reciter]
  end

  # Instance methods
  def display_text
    short_text.presence || text
  end

  def has_metadata?
    metadata.present? && metadata.any?
  end
end
