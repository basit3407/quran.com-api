# frozen_string_literal: true

# == Schema Information
#
# Table name: chapter_metadata
#
#  id            :bigint           not null, primary key
#  chapter_id    :integer          not null
#  metadata_type :string           not null
#  content       :text             not null
#  language_id   :integer          not null
#  is_active     :boolean          default(TRUE)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_chapter_metadata_on_chapter_id                      (chapter_id)
#  index_chapter_metadata_on_chapter_id_and_metadata_type    (chapter_id,metadata_type)
#  index_chapter_metadata_on_chapter_id_and_is_active        (chapter_id,is_active)
#  index_chapter_metadata_on_language_id                     (language_id)
#  index_chapter_metadata_on_chapter_type_active             (chapter_id,metadata_type,is_active)
#  index_chapter_metadata_on_language_active                 (language_id,is_active)
#
#

class ChapterMetadata < ApplicationRecord
  belongs_to :chapter
  belongs_to :language

  validates :chapter_id, presence: true
  validates :metadata_type, presence: true, inclusion: { in: %w[summary suggestion] }
  validates :content, presence: true
  validates :language_id, presence: true

  scope :summaries, -> { where(metadata_type: 'summary') }
  scope :suggestions, -> { where(metadata_type: 'suggestion') }
  scope :for_chapter, ->(chapter_id) { where(chapter_id: chapter_id) }
  scope :filter_by_language, ->(language_id) { where(language_id: language_id) }
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(created_at: :asc) }

  delegate :name, to: :language, prefix: true
end
