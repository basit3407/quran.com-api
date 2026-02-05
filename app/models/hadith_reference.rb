# frozen_string_literal: true

# == Schema Information
# Schema version: 20260205170000
#
# Table name: hadith_references
#
#  id                :bigint           not null, primary key
#  arabic_urn        :bigint           not null
#  ayah_end_index    :integer          not null
#  ayah_start_index  :integer          not null
#  collection        :string           not null
#  english_urn       :bigint           not null
#  hadith_number     :string           not null
#  our_hadith_number :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_hadith_refs_on_ayah_end_index                (ayah_end_index)
#  index_hadith_refs_on_ayah_start_index              (ayah_start_index)
#  index_hadith_refs_on_collection_and_hadith_number  (collection,hadith_number)
#
class HadithReference < ApplicationRecord
  validates :collection,
            :hadith_number,
            :our_hadith_number,
            :arabic_urn,
            :english_urn,
            :ayah_start_index,
            :ayah_end_index,
            presence: true

  validate :ayah_range_is_valid

  scope :for_verse_index, ->(verse_index) {
    where('ayah_start_index <= ? AND ayah_end_index >= ?', verse_index, verse_index)
  }

  private

  def ayah_range_is_valid
    return if ayah_start_index.blank? || ayah_end_index.blank?

    return if ayah_end_index >= ayah_start_index

    errors.add(:ayah_end_index, 'must be greater than or equal to ayah_start_index')
  end
end
