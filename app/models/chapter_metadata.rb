# frozen_string_literal: true

# == Schema Information
#
# Table name: chapter_metadata
#
#  id                  :bigint           not null, primary key
#  chapter_id          :integer          not null
#  metadata_type       :string           not null
#  content             :text             not null
#  language_id         :integer          not null
#  resource_content_id :integer
#  is_active           :boolean          default(TRUE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_chapter_metadata_on_query_pattern        (chapter_id,language_id,metadata_type,is_active)
#  index_chapter_metadata_on_resource_content_id  (resource_content_id)
#
#

class ChapterMetadata < ApplicationRecord
  include LanguageFilterable

  belongs_to :chapter
  belongs_to :resource_content, optional: true

  enum metadata_type: { summary: 'summary', suggestion: 'suggestion' }

  validates :content, presence: true

  scope :for_chapter, ->(chapter_id) { where(chapter_id: chapter_id) }
  scope :active, -> { where(is_active: true) }
  scope :suggestions, -> { suggestion }
  scope :summaries, -> { summary }
end
