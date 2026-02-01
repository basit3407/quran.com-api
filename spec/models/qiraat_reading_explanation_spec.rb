# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QiraatReadingExplanation, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:qiraat_reading_explanation_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:qiraat_readings).through(:qiraat_reading_explanation_memberships) }
    it { is_expected.to have_many(:localized_contents).dependent(:destroy) }
  end

  describe 'scopes' do
    before do
      # Clean up to ensure test isolation
      QiraatReadingExplanationMembership.delete_all
      QiraatReadingExplanation.delete_all
    end
    describe '.ordered' do
      it 'orders by position' do
        explanation2 = create(:qiraat_reading_explanation, position: 2)
        explanation1 = create(:qiraat_reading_explanation, position: 1)

        expect(described_class.ordered).to eq([explanation1, explanation2])
      end
    end

    describe '.by_source' do
      it 'filters by source' do
        alusi = create(:qiraat_reading_explanation, source: 'al-Alusi')
        _other = create(:qiraat_reading_explanation, source: 'Ibn Ashur')

        expect(described_class.by_source('al-Alusi')).to contain_exactly(alusi)
      end
    end
  end

  describe '#explanation_for' do
    let(:explanation) { create(:qiraat_reading_explanation, source: 'al-Alusi') }
    let(:language) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }

    context 'when localized content exists' do
      before do
        create(:localized_content,
               resource: explanation,
               language: language,
               content_type: 'explanation',
               text: 'The readings are complementary')
      end

      it 'returns the explanation with id, text, and source' do
        result = explanation.explanation_for(language)

        expect(result).to eq({
                               id: explanation.id,
                               text: 'The readings are complementary',
                               source: 'al-Alusi'
                             })
      end
    end

    context 'when localized content does not exist' do
      it 'returns nil' do
        expect(explanation.explanation_for(language)).to be_nil
      end
    end
  end

  describe '#shared?' do
    let(:explanation) { create(:qiraat_reading_explanation) }

    context 'when multiple readings share the explanation' do
      before do
        create_list(:qiraat_reading_explanation_membership, 2, qiraat_reading_explanation: explanation)
      end

      it 'returns true' do
        expect(explanation.shared?).to be true
      end
    end

    context 'when only one reading has the explanation' do
      before do
        create(:qiraat_reading_explanation_membership, qiraat_reading_explanation: explanation)
      end

      it 'returns false' do
        expect(explanation.shared?).to be false
      end
    end
  end

  describe '#add_reading' do
    let(:explanation) { create(:qiraat_reading_explanation) }
    let(:reading) { create(:qiraat_reading) }

    it 'creates a membership' do
      expect { explanation.add_reading(reading) }
        .to change(QiraatReadingExplanationMembership, :count).by(1)
    end

    it 'does not create duplicate memberships' do
      explanation.add_reading(reading)

      expect { explanation.add_reading(reading) }
        .not_to change(QiraatReadingExplanationMembership, :count)
    end
  end

  describe '#remove_reading' do
    let(:explanation) { create(:qiraat_reading_explanation) }
    let(:reading) { create(:qiraat_reading) }

    before do
      explanation.add_reading(reading)
    end

    it 'removes the membership' do
      expect { explanation.remove_reading(reading) }
        .to change(QiraatReadingExplanationMembership, :count).by(-1)
    end

    it 'returns nil when membership does not exist' do
      other_reading = create(:qiraat_reading)
      expect(explanation.remove_reading(other_reading)).to be_nil
    end
  end

  describe '#explanation_for_with_fallback' do
    let(:explanation) { create(:qiraat_reading_explanation, source: 'al-Alusi') }
    let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }
    let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar', name: 'Arabic') }
    let(:french) { Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr', name: 'French') }

    before do
      # Create English explanation
      create(:localized_content,
             resource: explanation,
             language: english,
             content_type: 'explanation',
             text: 'English explanation text')
    end

    context 'when requested language content exists' do
      before do
        create(:localized_content,
               resource: explanation,
               language: arabic,
               content_type: 'explanation',
               text: 'Arabic explanation text')
      end

      it 'returns the requested language explanation' do
        result = explanation.explanation_for_with_fallback(arabic)

        expect(result[:id]).to eq(explanation.id)
        expect(result[:text]).to eq('Arabic explanation text')
        expect(result[:source]).to eq('al-Alusi')
      end
    end

    context 'when requested language is Arabic and content is missing' do
      it 'does NOT fall back to English' do
        result = explanation.explanation_for_with_fallback(arabic)

        expect(result).to be_nil
      end
    end

    context 'when requested language is English and content is missing' do
      it 'returns English explanation (no fallback needed)' do
        result = explanation.explanation_for_with_fallback(english)

        expect(result[:id]).to eq(explanation.id)
        expect(result[:text]).to eq('English explanation text')
        expect(result[:source]).to eq('al-Alusi')
      end
    end

    context 'when requested language is non-Arabic and content is missing' do
      it 'falls back to English' do
        result = explanation.explanation_for_with_fallback(french)

        expect(result[:id]).to eq(explanation.id)
        expect(result[:text]).to eq('English explanation text')
        expect(result[:source]).to eq('al-Alusi')
      end
    end
  end

  describe '#explanation_text_for_with_fallback' do
    let(:explanation) { create(:qiraat_reading_explanation) }
    let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }
    let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar', name: 'Arabic') }
    let(:french) { Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr', name: 'French') }

    before do
      # Create English explanation
      create(:localized_content,
             resource: explanation,
             language: english,
             content_type: 'explanation',
             text: 'English only')
    end

    context 'when requested language is Arabic and content is missing' do
      it 'does NOT fall back to English' do
        result = explanation.explanation_text_for_with_fallback(arabic)

        expect(result).to be_nil
      end
    end

    context 'when requested language is non-Arabic and content is missing' do
      it 'falls back to English' do
        result = explanation.explanation_text_for_with_fallback(french)

        expect(result).to eq('English only')
      end
    end
  end
end
