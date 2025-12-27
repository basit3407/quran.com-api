# frozen_string_literal: true

# == Schema Information
# Schema version: 20251213172200
#
# Table name: qiraat_reading_translation_memberships
#
#  id                            :bigint           not null, primary key
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  qiraat_reading_id             :bigint           not null
#  qiraat_reading_translation_id :bigint           not null
#
# Indexes
#
#  idx_qr_trans_memb_on_reading    (qiraat_reading_id)
#  idx_qr_trans_memb_on_trans      (qiraat_reading_translation_id)
#  idx_qr_trans_membership_unique  (qiraat_reading_id,qiraat_reading_translation_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_7a5491c94e  (qiraat_reading_id => qiraat_readings.id)
#  fk_rails_90ada8d421  (qiraat_reading_translation_id => qiraat_reading_translations.id)
#

class QiraatReadingTranslationMembership < ApplicationRecord
  belongs_to :qiraat_reading
  belongs_to :qiraat_reading_translation

  validates :qiraat_reading_id, uniqueness: { scope: :qiraat_reading_translation_id }
end
