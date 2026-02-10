# frozen_string_literal: true

# == Schema Information
# Schema version: 20260206100000
#
# Table name: foot_notes
#
#  id                          :integer          not null, primary key
#  language_name               :string
#  text                        :text
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  language_id                 :integer
#  layered_translation_ayah_id :bigint
#  resource_content_id         :integer
#  translation_id              :integer
#
# Indexes
#
#  index_foot_notes_on_language_id                  (language_id)
#  index_foot_notes_on_layered_translation_ayah_id  (layered_translation_ayah_id)
#  index_foot_notes_on_resource_content_id          (resource_content_id)
#  index_foot_notes_on_translation_id               (translation_id)
#
# Foreign Keys
#
#  fk_rails_4abe0fd480  (layered_translation_ayah_id => layered_translation_ayahs.id)
#

class FootNote < ApplicationRecord
  include Resourceable

  belongs_to :translation, optional: true
  belongs_to :layered_translation_ayah, optional: true
  belongs_to :language
end
