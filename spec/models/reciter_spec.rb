# == Schema Information
#
# Table name: reciters
#
#  id                :integer          not null, primary key
#  bio               :text
#  cover_image       :string
#  name              :string
#  profile_picture   :string
#  recitations_count :integer          default(0)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reciter do
  context 'with associations' do
    it { is_expected.to have_many :translated_names }
    it { is_expected.to have_many(:localized_contents).dependent(:destroy) }
  end

  context 'with columns' do
    it { is_expected.to have_db_column(:name).of_type(:string) }
    it { is_expected.to have_db_column(:bio).of_type(:text) }
    it { is_expected.to have_db_column(:profile_picture).of_type(:string) }
    it { is_expected.to have_db_column(:cover_image).of_type(:string) }
    it { is_expected.to have_db_column(:recitations_count).of_type(:integer) }
  end

  context 'with scopes' do
    describe '.with_localized_content' do
      it 'preloads localized_contents association' do
        reciter = create(:reciter)
        create(:localized_content, :bio, resource: reciter)
        # Verify the scope preloads the association without triggering additional queries
        loaded_reciter = Reciter.with_localized_content.find(reciter.id)
        expect(loaded_reciter.association(:localized_contents).loaded?).to be true
        expect(loaded_reciter.localized_contents.size).to eq(1)
      end
    end
  end

  describe 'localized biography' do
    let!(:english) { Language.find_by(iso_code: 'en') || create(:language, :english) }
    let!(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, :arabic) }
    let(:reciter) { create(:reciter, bio: 'Static English bio') }

    describe '#bio_for' do
      context 'when localized content exists for requested language' do
        before do
          create(:localized_content, :bio,
                 resource: reciter,
                 language: arabic,
                 text: 'Arabic biography text')
        end

        it 'returns the localized content for the requested language' do
          reciter.reload
          result = reciter.bio_for(arabic)
          expect(result).to be_a(LocalizedContent)
          expect(result.text).to eq('Arabic biography text')
        end
      end

      context 'when localized content does not exist for requested language but exists for English' do
        before do
          create(:localized_content, :bio,
                 resource: reciter,
                 language: english,
                 text: 'English biography from localized content')
        end

        it 'falls back to English' do
          # Reload to get fresh localized_contents
          reciter.reload
          result = reciter.bio_for(arabic)
          expect(result).to be_a(LocalizedContent)
          expect(result.text).to eq('English biography from localized content')
        end
      end

      context 'when no localized content exists' do
        it 'returns nil' do
          result = reciter.bio_for(arabic)
          expect(result).to be_nil
        end
      end

      context 'when language is nil' do
        it 'returns nil' do
          result = reciter.bio_for(nil)
          expect(result).to be_nil
        end
      end
    end

    describe '#localized_bio' do
      context 'when localized content exists for requested language' do
        before do
          create(:localized_content, :bio,
                 resource: reciter,
                 language: arabic,
                 text: 'Arabic biography text')
          reciter.reload
        end

        it 'returns the localized text' do
          result = reciter.localized_bio(arabic)
          expect(result).to eq('Arabic biography text')
        end
      end

      context 'when localized content does not exist but English exists' do
        before do
          create(:localized_content, :bio,
                 resource: reciter,
                 language: english,
                 text: 'English biography from localized content')
          reciter.reload
        end

        it 'falls back to English localized content' do
          result = reciter.localized_bio(arabic)
          expect(result).to eq('English biography from localized content')
        end
      end

      context 'when no localized content exists' do
        it 'falls back to static bio column' do
          result = reciter.localized_bio(arabic)
          expect(result).to eq('Static English bio')
        end
      end

      context 'when language is nil' do
        it 'falls back to static bio column' do
          result = reciter.localized_bio(nil)
          expect(result).to eq('Static English bio')
        end
      end

      context 'when static bio is also nil' do
        let(:reciter_no_bio) { create(:reciter, bio: nil) }

        it 'returns nil' do
          result = reciter_no_bio.localized_bio(arabic)
          expect(result).to be_nil
        end
      end
    end
  end
end
