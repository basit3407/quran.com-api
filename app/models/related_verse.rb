# frozen_string_literal: true

# == Schema Information
# Schema version: 20260104000003
#
# Table name: related_verses
#
#  id               :bigint           not null, primary key
#  approved         :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  related_verse_id :bigint           not null
#  relation_type_id :bigint           not null
#  verse_id         :bigint           not null
#
# Indexes
#
#  index_related_verses_bidirectional_unique  (LEAST(verse_id, related_verse_id), GREATEST(verse_id, related_verse_id), relation_type_id) UNIQUE
#  index_related_verses_on_approved           (approved)
#  index_related_verses_on_related_verse_id   (related_verse_id)
#  index_related_verses_on_relation_type_id   (relation_type_id)
#  index_related_verses_on_verse_id           (verse_id)
#  index_related_verses_unique                (verse_id,related_verse_id,relation_type_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_baf905b48a  (relation_type_id => public.relation_types.id)
#  fk_rails_baf905b48a  (relation_type_id => relation_types.id)
#  fk_rails_c3e5a96f90  (verse_id => public.verses.id)
#  fk_rails_c3e5a96f90  (verse_id => verses.id)
#  fk_rails_f9e5b3df4e  (related_verse_id => public.verses.id)
#  fk_rails_f9e5b3df4e  (related_verse_id => verses.id)
#

class RelatedVerse < ApplicationRecord
  belongs_to :verse
  belongs_to :related_verse, class_name: 'Verse'
  belongs_to :relation_type

  validates :verse_id, uniqueness: { scope: [:related_verse_id, :relation_type_id] }
  validate :verses_are_different
  validate :reverse_relationship_does_not_exist

  # Bidirectional scope - get all relations for a verse (as source or target)
  scope :for_verse, ->(verse_id) {
    where(verse_id: verse_id).or(where(related_verse_id: verse_id))
  }

  # Scope for approved relationships only
  scope :approved, -> { where(approved: true) }

  # Get all related verses for a given verse, ordered by verse_index
  # Returns the "other" verse in each relationship
  # @param verse [Verse] The verse to find relations for
  # @param language [Language] The language for localized content
  # @return [Array<Hash>] Array of related verse data with relation types
  def self.related_to(verse, language: nil)
    relations = for_verse(verse.id)
                  .approved
                  .includes(:relation_type, :verse, :related_verse)
                  .joins(
                    sanitize_sql_array([
                      "INNER JOIN verses AS other_verse ON other_verse.id = " \
                      "CASE WHEN related_verses.verse_id = ? " \
                      "THEN related_verses.related_verse_id " \
                      "ELSE related_verses.verse_id END",
                      verse.id
                    ])
                  )
                  .order('other_verse.verse_index ASC')

    if language
      relations = relations.includes(relation_type: :localized_contents)
    end

    relations
  end

  # Returns the "other" verse in the relationship for a given verse_id
  # @param current_verse_id [Integer] The verse ID to compare against
  # @return [Verse] The other verse in the relationship
  def other_verse_for(current_verse_id)
    verse_id == current_verse_id ? related_verse : verse
  end

  private

  def verses_are_different
    if verse_id == related_verse_id
      errors.add(:related_verse_id, "can't be the same as verse")
    end
  end

  # Prevent creating reverse relationships since relationships are bidirectional
  # If 1:1 -> 1:2 exists, don't allow 1:2 -> 1:1 with the same relation_type
  #
  # Note: This validation provides user-friendly error messages but has a race condition.
  # The database-level constraint (index_related_verses_bidirectional_unique) is the 
  # primary protection using LEAST/GREATEST normalization.
  def reverse_relationship_does_not_exist
    return if verse_id.blank? || related_verse_id.blank? || relation_type_id.blank?

    reverse_exists = RelatedVerse.exists?(
      verse_id: related_verse_id,
      related_verse_id: verse_id,
      relation_type_id: relation_type_id
    )

    if reverse_exists
      errors.add(:base, "Relationship already exists (reverse direction)")
    end
  end
end
