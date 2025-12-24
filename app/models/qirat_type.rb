# frozen_string_literal: true
# == Schema Information
# Schema version: 20251218163500
#
# Table name: qirat_types
#
#  id                    :bigint           not null, primary key
#  description           :text
#  name                  :string
#  recitations_count     :integer          default(0)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  qiraat_transmitter_id :bigint
#
# Indexes
#
#  index_qirat_types_on_qiraat_transmitter_id  (qiraat_transmitter_id)
#
# Foreign Keys
#
#  fk_rails_76e5de8c21  (qiraat_transmitter_id => qiraat_transmitters.id)
#

class QiratType < ApplicationRecord
  # Associations
  belongs_to :qiraat_transmitter, optional: true

  # Delegations - derive reader from transmitter
  delegate :qiraat_reader, to: :qiraat_transmitter, allow_nil: true

  # Convenience methods
  def transmitter_name
    qiraat_transmitter&.name
  end

  def reader_name
    qiraat_reader&.name
  end
end
