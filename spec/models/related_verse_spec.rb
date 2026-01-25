# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RelatedVerse, type: :model do
  subject { build(:related_verse) }

  context 'with associations' do
    it { is_expected.to belong_to(:verse) }
    it { is_expected.to belong_to(:related_verse).class_name('Verse') }
    it { is_expected.to belong_to(:relation_type) }
  end

  context 'with validations' do
    it { is_expected.to validate_uniqueness_of(:verse_id).scoped_to([:related_verse_id, :relation_type_id]) }

    describe 'verses_are_different' do
      let(:verse) { create(:verse) }
      let(:relation_type) { create(:relation_type) }

      it 'is invalid when verse and related_verse are the same' do
        related_verse = build(:related_verse, verse: verse, related_verse: verse, relation_type: relation_type)
        expect(related_verse).not_to be_valid
        expect(related_verse.errors[:related_verse_id]).to include("can't be the same as verse")
      end
    end

    describe 'reverse_relationship_does_not_exist' do
      let(:verse_a) { create(:verse) }
      let(:verse_b) { create(:verse) }
      let(:relation_type) { create(:relation_type) }

      before do
        create(:related_verse, verse: verse_a, related_verse: verse_b, relation_type: relation_type)
      end

      it 'is invalid when reverse relationship already exists' do
        reverse_relation = build(:related_verse, verse: verse_b, related_verse: verse_a, relation_type: relation_type)
        expect(reverse_relation).not_to be_valid
        expect(reverse_relation.errors[:base]).to include("Relationship already exists (reverse direction)")
      end

      it 'is valid with different relation_type' do
        other_relation_type = create(:relation_type)
        reverse_relation = build(:related_verse, verse: verse_b, related_verse: verse_a, relation_type: other_relation_type)
        expect(reverse_relation).to be_valid
      end
    end
  end

  context 'with scopes' do
    describe '.for_verse' do
      let(:verse) { create(:verse) }
      let(:other_verse_1) { create(:verse) }
      let(:other_verse_2) { create(:verse) }
      let(:unrelated_verse) { create(:verse) }
      let(:relation_type) { create(:relation_type) }

      before do
        create(:related_verse, verse: verse, related_verse: other_verse_1, relation_type: relation_type)
        create(:related_verse, verse: other_verse_2, related_verse: verse, relation_type: relation_type)
        create(:related_verse, verse: unrelated_verse, related_verse: other_verse_1, relation_type: relation_type)
      end

      it 'returns all relationships where verse is source or target' do
        result = described_class.for_verse(verse.id)
        expect(result.count).to eq(2)
      end

      it 'does not return unrelated relationships' do
        result = described_class.for_verse(verse.id)
        expect(result.map(&:id)).not_to include(
          described_class.find_by(verse: unrelated_verse, related_verse: other_verse_1)&.id
        )
      end
    end

    describe '.approved' do
      let(:approved_relation) { create(:related_verse, :approved) }
      let(:unapproved_relation) { create(:related_verse, approved: false) }

      it 'returns only approved relationships' do
        result = described_class.approved
        expect(result).to include(approved_relation)
        expect(result).not_to include(unapproved_relation)
      end
    end
  end

  describe '.related_to' do
    let(:verse) { create(:verse, verse_index: 1) }
    let(:related_1) { create(:verse, verse_index: 10) }
    let(:related_2) { create(:verse, verse_index: 5) }
    let(:relation_type) { create(:relation_type) }

    before do
      create(:related_verse, :approved, verse: verse, related_verse: related_1, relation_type: relation_type)
      create(:related_verse, :approved, verse: related_2, related_verse: verse, relation_type: relation_type)
      create(:related_verse, approved: false, verse: verse, related_verse: create(:verse), relation_type: relation_type)
    end

    it 'returns only approved relationships' do
      result = described_class.related_to(verse)
      expect(result.count).to eq(2)
    end

    it 'orders by other verse verse_index' do
      result = described_class.related_to(verse)
      other_indices = result.map { |rv| rv.other_verse_for(verse.id).verse_index }
      expect(other_indices).to eq(other_indices.sort)
    end
  end

  describe '#other_verse_for' do
    let(:verse_a) { create(:verse) }
    let(:verse_b) { create(:verse) }
    let(:related_verse_record) { create(:related_verse, verse: verse_a, related_verse: verse_b) }

    it 'returns related_verse when given verse_id matches source' do
      expect(related_verse_record.other_verse_for(verse_a.id)).to eq(verse_b)
    end

    it 'returns verse when given verse_id matches target' do
      expect(related_verse_record.other_verse_for(verse_b.id)).to eq(verse_a)
    end
  end
end
