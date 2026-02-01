# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QiraatReadingTranslation, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:qiraat_reading_translation_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:qiraat_readings).through(:qiraat_reading_translation_memberships) }
    it { is_expected.to have_many(:localized_contents).dependent(:destroy) }
  end

  describe 'scopes' do
    before do
      # Clean up to ensure test isolation
      QiraatReadingTranslationMembership.delete_all
      QiraatReadingTranslation.delete_all
    end

    describe '.ordered' do
      it 'orders by position' do
        translation2 = create(:qiraat_reading_translation, position: 2)
        translation1 = create(:qiraat_reading_translation, position: 1)

        expect(described_class.ordered).to eq([translation1, translation2])
      end
    end

    describe '.by_source' do
      it 'filters by source' do
        bridges = create(:qiraat_reading_translation, source: 'Bridges')
        create(:qiraat_reading_translation, source: 'Other')

        expect(described_class.by_source('Bridges')).to eq([bridges])
      end
    end
  end

  describe '#translation_for' do
    let(:translation) { create(:qiraat_reading_translation, source: 'Bridges') }
    let(:language) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }

    context 'when localized content exists' do
      before do
        create(:localized_content,
               resource: translation,
               language: language,
               content_type: 'translation',
               text: 'English translation text')
      end

      it 'returns a hash with id, text, and source' do
        result = translation.translation_for(language)

        expect(result[:id]).to eq(translation.id)
        expect(result[:text]).to eq('English translation text')
        expect(result[:source]).to eq('Bridges')
      end
    end

    context 'when localized content does not exist' do
      it 'returns nil' do
        expect(translation.translation_for(language)).to be_nil
      end
    end
  end

  describe '#translation_text_for' do
    let(:translation) { create(:qiraat_reading_translation) }
    let(:language) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }

    context 'when localized content exists' do
      before do
        create(:localized_content,
               resource: translation,
               language: language,
               content_type: 'translation',
               text: 'Just the text')
      end

      it 'returns just the text' do
        expect(translation.translation_text_for(language)).to eq('Just the text')
      end
    end

    context 'when localized content does not exist' do
      it 'returns nil' do
        expect(translation.translation_text_for(language)).to be_nil
      end
    end
  end

  describe '#shared?' do
    let(:translation) { create(:qiraat_reading_translation) }

    context 'when used by multiple readings' do
      before do
        reading1 = create(:qiraat_reading)
        reading2 = create(:qiraat_reading)
        translation.add_reading(reading1)
        translation.add_reading(reading2)
      end

      it 'returns true' do
        expect(translation.shared?).to be true
      end
    end

    context 'when used by a single reading' do
      before do
        reading = create(:qiraat_reading)
        translation.add_reading(reading)
      end

      it 'returns false' do
        expect(translation.shared?).to be false
      end
    end
  end

  describe '#add_reading' do
    let(:translation) { create(:qiraat_reading_translation) }
    let(:reading) { create(:qiraat_reading) }

    it 'creates a membership' do
      expect { translation.add_reading(reading) }
        .to change(QiraatReadingTranslationMembership, :count).by(1)
    end

    it 'does not create duplicate memberships' do
      translation.add_reading(reading)

      expect { translation.add_reading(reading) }
        .not_to change(QiraatReadingTranslationMembership, :count)
    end
  end

  describe '#remove_reading' do
    let(:translation) { create(:qiraat_reading_translation) }
    let(:reading) { create(:qiraat_reading) }

    before do
      translation.add_reading(reading)
    end

    it 'removes the membership' do
      expect { translation.remove_reading(reading) }
        .to change(QiraatReadingTranslationMembership, :count).by(-1)
    end
  end

  describe '#translation_for_with_fallback' do
    let(:translation) { create(:qiraat_reading_translation, source: 'Bridges') }
    let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }
    let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar', name: 'Arabic') }
    let(:french) { Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr', name: 'French') }

    before do
      # Create English translation
      create(:localized_content,
             resource: translation,
             language: english,
             content_type: 'translation',
             text: 'English translation text')
    end

    context 'when requested language content exists' do
      before do
        create(:localized_content,
               resource: translation,
               language: arabic,
               content_type: 'translation',
               text: 'Arabic translation text')
      end

      it 'returns the requested language translation' do
        result = translation.translation_for_with_fallback(arabic)

        expect(result[:id]).to eq(translation.id)
        expect(result[:text]).to eq('Arabic translation text')
        expect(result[:source]).to eq('Bridges')
      end
    end

    context 'when requested language is Arabic and content is missing' do
      it 'does NOT fall back to English' do
        result = translation.translation_for_with_fallback(arabic)

        expect(result).to be_nil
      end
    end

    context 'when requested language is English and content is missing' do
      it 'returns English translation (no fallback needed)' do
        result = translation.translation_for_with_fallback(english)

        expect(result[:id]).to eq(translation.id)
        expect(result[:text]).to eq('English translation text')
        expect(result[:source]).to eq('Bridges')
      end
    end

    context 'when requested language is non-Arabic and content is missing' do
      it 'falls back to English' do
        result = translation.translation_for_with_fallback(french)

        expect(result[:id]).to eq(translation.id)
        expect(result[:text]).to eq('English translation text')
        expect(result[:source]).to eq('Bridges')
      end
    end
  end

  describe '#translation_text_for_with_fallback' do
    let(:translation) { create(:qiraat_reading_translation) }
    let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en', name: 'English') }
    let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar', name: 'Arabic') }
    let(:french) { Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr', name: 'French') }

    before do
      # Create English translation
      create(:localized_content,
             resource: translation,
             language: english,
             content_type: 'translation',
             text: 'English only')
    end

    context 'when requested language is Arabic and content is missing' do
      it 'does NOT fall back to English' do
        result = translation.translation_text_for_with_fallback(arabic)

        expect(result).to be_nil
      end
    end

    context 'when requested language is non-Arabic and content is missing' do
      it 'falls back to English' do
        result = translation.translation_text_for_with_fallback(french)

        expect(result).to eq('English only')
      end
    end
  end
end
