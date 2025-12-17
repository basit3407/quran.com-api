# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QiraatReading, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:qiraat_juncture) }
    it { is_expected.to have_many(:qiraat_reading_attributions).dependent(:destroy) }
    it { is_expected.to have_many(:qiraat_readers).through(:qiraat_reading_attributions) }
    it { is_expected.to have_many(:qiraat_transmitters).through(:qiraat_reading_attributions) }
    it { is_expected.to have_many(:localized_contents).dependent(:destroy) }

    # New shared explanations associations
    it { is_expected.to have_many(:qiraat_reading_explanation_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:qiraat_reading_explanations).through(:qiraat_reading_explanation_memberships) }

    # New shared translations associations
    it { is_expected.to have_many(:qiraat_reading_translation_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:qiraat_reading_translations).through(:qiraat_reading_translation_memberships) }
  end

  describe 'validations' do
    subject { build(:qiraat_reading) }

    it { is_expected.to validate_presence_of(:text_uthmani) }

    # position is auto-assigned by callback, so presence validation is always satisfied
    it 'auto-assigns position if not provided' do
      reading = build(:qiraat_reading, position: nil)
      reading.valid?
      expect(reading.position).to be_present
    end

    it 'validates uniqueness of position within juncture' do
      juncture = create(:qiraat_juncture)
      create(:qiraat_reading, qiraat_juncture: juncture, position: 1)
      duplicate = build(:qiraat_reading, qiraat_juncture: juncture, position: 1)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:position]).to include('must be unique per juncture')
    end
  end

  describe 'scopes' do
    describe '.with_explanations' do
      it 'eager loads explanations with localized content' do
        reading = create(:qiraat_reading)
        explanation = create(:qiraat_reading_explanation)
        reading.add_explanation(explanation)

        result = described_class.with_explanations.find(reading.id)
        expect(result.qiraat_reading_explanations).to be_loaded
      end
    end
  end

  describe '#explanations_for' do
    let(:reading) { create(:qiraat_reading) }
    let(:language) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }

    context 'when reading has shared explanations' do
      let(:explanation1) { create(:qiraat_reading_explanation, source: 'al-Alusi', position: 1) }
      let(:explanation2) { create(:qiraat_reading_explanation, source: 'Ibn Ashur', position: 2) }

      before do
        reading.add_explanation(explanation1)
        reading.add_explanation(explanation2)

        create(:localized_content,
               resource: explanation1,
               language: language,
               content_type: 'explanation',
               text: 'First explanation text')

        create(:localized_content,
               resource: explanation2,
               language: language,
               content_type: 'explanation',
               text: 'Second explanation text')
      end

      it 'returns all explanations in order' do
        explanations = reading.explanations_for(language)

        expect(explanations.length).to eq(2)
        expect(explanations[0][:text]).to eq('First explanation text')
        expect(explanations[0][:source]).to eq('al-Alusi')
        expect(explanations[1][:text]).to eq('Second explanation text')
        expect(explanations[1][:source]).to eq('Ibn Ashur')
      end
    end

    context 'when reading has no explanations' do
      it 'returns an empty array' do
        expect(reading.explanations_for(language)).to eq([])
      end
    end
  end

  describe '#explanation_for' do
    let(:reading) { create(:qiraat_reading) }
    let(:language) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }

    context 'when reading has a shared explanation' do
      let(:explanation) { create(:qiraat_reading_explanation, source: 'al-Alusi') }

      before do
        reading.add_explanation(explanation)
        create(:localized_content,
               resource: explanation,
               language: language,
               content_type: 'explanation',
               text: 'Shared explanation text')
      end

      it 'returns the first shared explanation' do
        result = reading.explanation_for(language)

        expect(result[:text]).to eq('Shared explanation text')
        expect(result[:source]).to eq('al-Alusi')
      end
    end

    context 'when reading has no explanation' do
      it 'returns nil' do
        expect(reading.explanation_for(language)).to be_nil
      end
    end
  end

  describe '#add_explanation' do
    let(:reading) { create(:qiraat_reading) }
    let(:explanation) { create(:qiraat_reading_explanation) }

    it 'creates a membership' do
      expect { reading.add_explanation(explanation) }
        .to change(QiraatReadingExplanationMembership, :count).by(1)
    end

    it 'does not create duplicate memberships' do
      reading.add_explanation(explanation)

      expect { reading.add_explanation(explanation) }
        .not_to change(QiraatReadingExplanationMembership, :count)
    end
  end

  describe '#remove_explanation' do
    let(:reading) { create(:qiraat_reading) }
    let(:explanation) { create(:qiraat_reading_explanation) }

    before do
      reading.add_explanation(explanation)
    end

    it 'removes the membership' do
      expect { reading.remove_explanation(explanation) }
        .to change(QiraatReadingExplanationMembership, :count).by(-1)
    end
  end

  describe 'shared explanations scenario' do
    let(:language) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }
    let(:juncture) { create(:qiraat_juncture) }
    let(:reading1) { create(:qiraat_reading, qiraat_juncture: juncture, position: 1) }
    let(:reading2) { create(:qiraat_reading, qiraat_juncture: juncture, position: 2) }
    let(:shared_explanation) { create(:qiraat_reading_explanation, source: 'al-Alusi') }

    before do
      create(:localized_content,
             resource: shared_explanation,
             language: language,
             content_type: 'explanation',
             text: 'This explanation applies to both readings')

      # Both readings share the same explanation
      reading1.add_explanation(shared_explanation)
      reading2.add_explanation(shared_explanation)
    end

    it 'both readings can access the same explanation' do
      expect(reading1.explanation_for(language)[:text]).to eq('This explanation applies to both readings')
      expect(reading2.explanation_for(language)[:text]).to eq('This explanation applies to both readings')
    end

    it 'the explanation knows it is shared' do
      expect(shared_explanation.shared?).to be true
    end

    it 'the explanation lists both readings' do
      expect(shared_explanation.qiraat_readings).to contain_exactly(reading1, reading2)
    end
  end
end
