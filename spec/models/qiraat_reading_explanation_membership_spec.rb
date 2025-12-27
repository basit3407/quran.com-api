# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QiraatReadingExplanationMembership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:qiraat_reading) }
    it { is_expected.to belong_to(:qiraat_reading_explanation) }
  end

  describe 'validations' do
    it 'validates uniqueness of reading-explanation pair' do
      reading = create(:qiraat_reading)
      explanation = create(:qiraat_reading_explanation)
      create(:qiraat_reading_explanation_membership, qiraat_reading: reading, qiraat_reading_explanation: explanation)

      duplicate = build(:qiraat_reading_explanation_membership, qiraat_reading: reading, qiraat_reading_explanation: explanation)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:qiraat_reading_id]).to include('already has this explanation')
    end
  end

  describe 'scopes' do
    let(:reading1) { create(:qiraat_reading) }
    let(:reading2) { create(:qiraat_reading) }
    let(:explanation1) { create(:qiraat_reading_explanation) }
    let(:explanation2) { create(:qiraat_reading_explanation) }

    before do
      create(:qiraat_reading_explanation_membership, qiraat_reading: reading1, qiraat_reading_explanation: explanation1)
      create(:qiraat_reading_explanation_membership, qiraat_reading: reading2, qiraat_reading_explanation: explanation1)
      create(:qiraat_reading_explanation_membership, qiraat_reading: reading1, qiraat_reading_explanation: explanation2)
    end

    describe '.for_reading' do
      it 'returns memberships for a specific reading' do
        memberships = described_class.for_reading(reading1.id)
        expect(memberships.count).to eq(2)
      end
    end

    describe '.for_explanation' do
      it 'returns memberships for a specific explanation' do
        memberships = described_class.for_explanation(explanation1.id)
        expect(memberships.count).to eq(2)
      end
    end
  end

  describe 'unique constraint' do
    let(:reading) { create(:qiraat_reading) }
    let(:explanation) { create(:qiraat_reading_explanation) }

    before do
      create(:qiraat_reading_explanation_membership, qiraat_reading: reading, qiraat_reading_explanation: explanation)
    end

    it 'prevents duplicate memberships' do
      duplicate = build(:qiraat_reading_explanation_membership, qiraat_reading: reading, qiraat_reading_explanation: explanation)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:qiraat_reading_id]).to include('already has this explanation')
    end
  end
end
