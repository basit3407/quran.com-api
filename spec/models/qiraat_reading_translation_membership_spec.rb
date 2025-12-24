# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QiraatReadingTranslationMembership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:qiraat_reading) }
    it { is_expected.to belong_to(:qiraat_reading_translation) }
  end

  describe 'validations' do
    subject { create(:qiraat_reading_translation_membership) }

    it 'validates uniqueness of reading_id scoped to translation_id' do
      reading = create(:qiraat_reading)
      translation = create(:qiraat_reading_translation)

      create(:qiraat_reading_translation_membership,
             qiraat_reading: reading,
             qiraat_reading_translation: translation)

      duplicate = build(:qiraat_reading_translation_membership,
                       qiraat_reading: reading,
                       qiraat_reading_translation: translation)

      expect(duplicate).not_to be_valid
    end

    it 'allows same reading with different translations' do
      reading = create(:qiraat_reading)
      translation1 = create(:qiraat_reading_translation)
      translation2 = create(:qiraat_reading_translation)

      create(:qiraat_reading_translation_membership,
             qiraat_reading: reading,
             qiraat_reading_translation: translation1)

      membership = build(:qiraat_reading_translation_membership,
                        qiraat_reading: reading,
                        qiraat_reading_translation: translation2)

      expect(membership).to be_valid
    end

    it 'allows same translation with different readings' do
      reading1 = create(:qiraat_reading)
      reading2 = create(:qiraat_reading)
      translation = create(:qiraat_reading_translation)

      create(:qiraat_reading_translation_membership,
             qiraat_reading: reading1,
             qiraat_reading_translation: translation)

      membership = build(:qiraat_reading_translation_membership,
                        qiraat_reading: reading2,
                        qiraat_reading_translation: translation)

      expect(membership).to be_valid
    end
  end
end
