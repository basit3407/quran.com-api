# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QiraatJunctureSegment, type: :model do
  def create_verse!(verse_key:)
    chapter_number, verse_number = verse_key.split(':').map(&:to_i)

    chapter = Chapter.find_or_create_by!(id: chapter_number, chapter_number: chapter_number) do |c|
      c.name_simple = "Chapter #{chapter_number}"
      c.verses_count = 286
    end

    Verse.create!(chapter_id: chapter.id, verse_number: verse_number) do |v|
      v.verse_key = verse_key
      v.text_uthmani = 'Test verse'
    end
  end

  def create_word_for_verse!(verse:, position:)
    topic = Topic.new(name: 'Test topic')
    topic.save!(validate: false)

    char_type = CharType.new(name: 'Test char type')
    char_type.save!(validate: false)

    token = Token.create!(text: 'token')

    word = Word.new(
      verse: verse,
      verse_id: verse.id,
      verse_key: verse.verse_key,
      chapter_id: verse.chapter_id,
      position: position,
      topic: topic,
      char_type: char_type,
      token: token,
      text_uthmani: "Word #{position}"
    )
    word.save!(validate: false)
    word
  end

  before do
    # Clean up in correct order to respect foreign keys
    QiraatReadingTranslationMembership.delete_all
    QiraatReadingExplanationMembership.delete_all
    QiraatReadingAttribution.delete_all
    QiraatJunctureSegment.delete_all
    QiraatReading.delete_all
    QiraatJuncture.delete_all
  end

  describe 'validations' do
    it 'is valid with proper associations' do
      verse = create_verse!(verse_key: '10:35')
      word1 = create_word_for_verse!(verse: verse, position: 1)
      word2 = create_word_for_verse!(verse: verse, position: 2)
      juncture = QiraatJuncture.create!(position: 1)

      segment = described_class.new(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: word1,
        end_word: word2,
        position: 0
      )

      expect(segment).to be_valid
    end

    it 'is invalid when start_word is from different verse' do
      verse1 = create_verse!(verse_key: '10:35')
      verse2 = create_verse!(verse_key: '10:36')
      word1 = create_word_for_verse!(verse: verse1, position: 1)
      word2 = create_word_for_verse!(verse: verse2, position: 1)
      juncture = QiraatJuncture.create!(position: 1)

      segment = described_class.new(
        qiraat_juncture: juncture,
        verse: verse2,
        start_word: word1,
        end_word: word2,
        position: 0
      )

      expect(segment).not_to be_valid
      expect(segment.errors[:start_word]).to include('must belong to the segment verse')
    end

    it 'is invalid when end_word is before start_word' do
      verse = create_verse!(verse_key: '10:35')
      word1 = create_word_for_verse!(verse: verse, position: 1)
      word2 = create_word_for_verse!(verse: verse, position: 5)
      juncture = QiraatJuncture.create!(position: 1)

      segment = described_class.new(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: word2,
        end_word: word1,
        position: 0
      )

      expect(segment).not_to be_valid
      expect(segment.errors[:end_word]).to include('must be at or after start_word')
    end
  end

  describe '#words' do
    it 'returns all words in range' do
      verse = create_verse!(verse_key: '10:35')
      word1 = create_word_for_verse!(verse: verse, position: 1)
      word2 = create_word_for_verse!(verse: verse, position: 2)
      word3 = create_word_for_verse!(verse: verse, position: 3)
      juncture = QiraatJuncture.create!(position: 1)

      segment = described_class.create!(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: word1,
        end_word: word3,
        position: 0
      )

      expect(segment.words.count).to eq(3)
      expect(segment.words).to include(word1, word2, word3)
    end
  end

  describe '#single_word?' do
    it 'returns true for single word segment' do
      verse = create_verse!(verse_key: '10:35')
      word1 = create_word_for_verse!(verse: verse, position: 1)
      juncture = QiraatJuncture.create!(position: 1)

      segment = described_class.create!(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: word1,
        end_word: word1,
        position: 0
      )

      expect(segment.single_word?).to be true
    end
  end
end
