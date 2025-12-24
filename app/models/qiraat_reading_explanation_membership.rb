# frozen_string_literal: true

# == Schema Information
# Schema version: 20251213100000
#
# Table name: qiraat_reading_explanation_memberships
#
#  id                            :bigint           not null, primary key
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  qiraat_reading_explanation_id :bigint           not null
#  qiraat_reading_id             :bigint           not null
#
# Indexes
#
#  idx_qr_expl_memb_explanation   (qiraat_reading_explanation_id)
#  idx_qr_expl_memb_reading       (qiraat_reading_id)
#  idx_qr_expl_membership_unique  (qiraat_reading_id,qiraat_reading_explanation_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_9a045db031  (qiraat_reading_explanation_id => qiraat_reading_explanations.id)
#  fk_rails_a3889640ef  (qiraat_reading_id => qiraat_readings.id)
#

class QiraatReadingExplanationMembership < ApplicationRecord
  # Associations
  belongs_to :qiraat_reading
  belongs_to :qiraat_reading_explanation

  # Validations
  validates :qiraat_reading_id, uniqueness: {
    scope: :qiraat_reading_explanation_id,
    message: 'already has this explanation'
  }

  # Scopes
  scope :for_reading, ->(reading_id) { where(qiraat_reading_id: reading_id) }
  scope :for_explanation, ->(explanation_id) { where(qiraat_reading_explanation_id: explanation_id) }

  # Delegations
  delegate :text_uthmani, :verse_key, to: :qiraat_reading, prefix: :reading
  delegate :source, to: :qiraat_reading_explanation, prefix: :explanation
end
