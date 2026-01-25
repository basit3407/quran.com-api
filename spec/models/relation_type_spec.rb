# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RelationType, type: :model do
  subject { build(:relation_type) }

  context 'with associations' do
    it { is_expected.to have_many(:localized_contents).dependent(:destroy) }
    it { is_expected.to have_one(:localized_content).conditions(content_type: 'translation') }
    it { is_expected.to have_many(:related_verses).dependent(:restrict_with_error) }
  end

  context 'with validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe '#localized_name_for' do
    let!(:english) { Language.find_by(iso_code: 'en') || create(:language, :english) }
    let(:relation_type) { create(:relation_type, name: 'similar_topic') }
    let(:arabic) { create(:language, iso_code: 'ar') }

    context 'when language is nil' do
      it 'returns titleized name' do
        expect(relation_type.localized_name_for(nil)).to eq('Similar Topic')
      end
    end

    context 'when translation exists for requested language' do
      before do
        create(:localized_content,
               resource: relation_type,
               language: arabic,
               text: 'موضوع مشابه',
               content_type: 'translation')
      end

      it 'returns the translated name' do
        expect(relation_type.localized_name_for(arabic)).to eq('موضوع مشابه')
      end
    end

    context 'when translation does not exist but English fallback exists' do
      before do
        create(:localized_content,
               resource: relation_type,
               language: english,
               text: 'Similar Topic',
               content_type: 'translation')
      end

      it 'returns English translation' do
        expect(relation_type.localized_name_for(arabic)).to eq('Similar Topic')
      end
    end

    context 'when no translations exist' do
      it 'returns titleized name as last resort' do
        expect(relation_type.localized_name_for(arabic)).to eq('Similar Topic')
      end
    end

    context 'when translations are already loaded' do
      before do
        create(:localized_content,
               resource: relation_type,
               language: arabic,
               text: 'موضوع مشابه',
               content_type: 'translation')
        relation_type.localized_contents.load
      end

      it 'finds translation in memory' do
        result = relation_type.localized_name_for(arabic)
        expect(result).to eq('موضوع مشابه')
      end
    end
  end
end
