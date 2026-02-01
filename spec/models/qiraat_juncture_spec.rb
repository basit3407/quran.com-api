# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QiraatJuncture, type: :model do
  before do
    # Clean up in correct order to respect foreign keys
    QiraatReadingTranslationMembership.delete_all
    QiraatReadingExplanationMembership.delete_all
    QiraatReadingAttribution.delete_all
    QiraatJunctureSegment.delete_all
    QiraatReading.delete_all
    QiraatJuncture.delete_all
  end

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

  describe 'single-verse juncture with segment' do
    it 'creates a valid juncture with one segment' do
      verse = create_verse!(verse_key: '10:35')
      word1 = create_word_for_verse!(verse: verse, position: 1)
      word2 = create_word_for_verse!(verse: verse, position: 2)

      juncture = described_class.create!(position: 1)
      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: word1,
        end_word: word2,
        position: 0
      )

      expect(juncture).to be_valid
      expect(juncture.verse_key).to eq('10:35')
      expect(juncture.verse_range).to eq('10:35')
      expect(juncture.cross_verse?).to be false
    end
  end

  describe 'cross-verse juncture with multiple segments' do
    it 'creates a valid juncture spanning two verses' do
      verse1 = create_verse!(verse_key: '8:65')
      verse2 = create_verse!(verse_key: '8:66')
      word1_v1 = create_word_for_verse!(verse: verse1, position: 1)
      word2_v1 = create_word_for_verse!(verse: verse1, position: 2)
      word1_v2 = create_word_for_verse!(verse: verse2, position: 1)
      word2_v2 = create_word_for_verse!(verse: verse2, position: 2)

      juncture = described_class.create!(position: 1)

      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse1,
        start_word: word1_v1,
        end_word: word2_v1,
        position: 0
      )

      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse2,
        start_word: word1_v2,
        end_word: word2_v2,
        position: 1
      )

      juncture.reload

      expect(juncture.cross_verse?).to be true
      expect(juncture.verse_range).to eq('8:65-66')
      expect(juncture.qiraat_juncture_segments.count).to eq(2)
    end
  end

  describe '#all_words' do
    it 'returns words from all segments' do
      verse1 = create_verse!(verse_key: '8:65')
      verse2 = create_verse!(verse_key: '8:66')
      word1 = create_word_for_verse!(verse: verse1, position: 1)
      word2 = create_word_for_verse!(verse: verse2, position: 1)

      juncture = described_class.create!(position: 1)

      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse1,
        start_word: word1,
        end_word: word1,
        position: 0
      )

      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse2,
        start_word: word2,
        end_word: word2,
        position: 1
      )

      juncture.reload
      all_words = juncture.all_words

      expect(all_words.count).to eq(2)
      expect(all_words).to include(word1, word2)
    end
  end

  describe '#primary_verse' do
    it 'returns the first segment verse' do
      verse1 = create_verse!(verse_key: '8:65')
      verse2 = create_verse!(verse_key: '8:66')
      word1 = create_word_for_verse!(verse: verse1, position: 1)
      word2 = create_word_for_verse!(verse: verse2, position: 1)

      juncture = described_class.create!(position: 1)

      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse1,
        start_word: word1,
        end_word: word1,
        position: 0
      )

      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse2,
        start_word: word2,
        end_word: word2,
        position: 1
      )

      juncture.reload

      expect(juncture.primary_verse).to eq(verse1)
    end
  end

  describe '#explanation_for' do
    let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en') }
    let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar') }
    let(:french) { Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr') }
    let(:juncture) { described_class.create!(position: 1) }

    it 'returns explanation in requested language when available' do
      create(:localized_content,
        resource: juncture,
        language: french,
        content_type: 'explanation',
        text: 'Explication française')

      result = juncture.explanation_for(french)

      expect(result).to be_present
      expect(result.text).to eq('Explication française')
    end

    it 'returns nil when explanation in requested language is not found' do
      result = juncture.explanation_for(french)
      expect(result).to be_nil
    end

    it 'does not fall back to English for Arabic when content is missing' do
      create(:localized_content,
        resource: juncture,
        language: english,
        content_type: 'explanation',
        text: 'English explanation')

      result = juncture.explanation_for(arabic)

      expect(result).to be_nil
    end

    it 'does not fall back to English for English (trivial case)' do
      result = juncture.explanation_for(english)
      expect(result).to be_nil
    end

    it 'falls back to English for other languages when content is missing' do
      create(:localized_content,
        resource: juncture,
        language: english,
        content_type: 'explanation',
        text: 'English explanation')

      result = juncture.explanation_for(french)

      expect(result).to be_present
      expect(result.text).to eq('English explanation')
    end
  end

  describe '#combined_translation_for' do
    let(:english) { Language.find_by(iso_code: 'en') || create(:language, iso_code: 'en') }
    let(:arabic) { Language.find_by(iso_code: 'ar') || create(:language, iso_code: 'ar') }
    let(:french) { Language.find_by(iso_code: 'fr') || create(:language, iso_code: 'fr') }
    let(:juncture) { described_class.create!(position: 1) }

    it 'returns combined_translation in requested language when available' do
      create(:localized_content,
        resource: juncture,
        language: french,
        content_type: 'combined_translation',
        text: 'Traduction combinée française')

      result = juncture.combined_translation_for(french)

      expect(result).to be_present
      expect(result.text).to eq('Traduction combinée française')
    end

    it 'returns nil when combined_translation in requested language is not found' do
      result = juncture.combined_translation_for(french)
      expect(result).to be_nil
    end

    it 'does not fall back to English for Arabic when content is missing' do
      create(:localized_content,
        resource: juncture,
        language: english,
        content_type: 'combined_translation',
        text: 'English combined translation')

      result = juncture.combined_translation_for(arabic)

      expect(result).to be_nil
    end

    it 'does not fall back to English for English (trivial case)' do
      result = juncture.combined_translation_for(english)
      expect(result).to be_nil
    end

    it 'falls back to English for other languages when content is missing' do
      create(:localized_content,
        resource: juncture,
        language: english,
        content_type: 'combined_translation',
        text: 'English combined translation')

      result = juncture.combined_translation_for(french)

      expect(result).to be_present
      expect(result.text).to eq('English combined translation')
    end
  end
end
