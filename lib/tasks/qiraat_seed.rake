# frozen_string_literal: true

# Qiraat (Quranic Reading Variations) Seed Data
# This file seeds the database with:
# 1. The 10 canonical Qiraat readers
# 2. Their primary and secondary transmitters
# 3. Juncture data with segments

# Helper module for qiraat seeding
module QiraatSeedHelpers
  # Seed color palette
  SEED_COLORS = {
    white: '#FFFFFF',
    green: '#B7D7A8',
    pink: '#ea9999',
    blue: '#A4C2F4'
  }.freeze

  # Helper method to create a juncture with segments
  def self.create_juncture_with_segments(segments:, position: 1, flags: [])
    juncture = QiraatJuncture.create!(
      position: position,
      flags: flags
    )

    segments.each_with_index do |seg, idx|
      verse = seg[:verse]
      start_word = verse.words.find_by!(position: seg[:start_position])
      end_word = verse.words.find_by!(position: seg[:end_position])

      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: start_word,
        end_word: end_word,
        position: idx
      )
    end

    juncture.reload
    juncture
  end

  # Helper method to clear existing juncture data for a verse
  def self.clear_juncture_data_for_verse(verse)
    juncture_ids = QiraatJunctureSegment.where(verse_id: verse.id).pluck(:qiraat_juncture_id).uniq

    juncture_ids.each do |juncture_id|
      juncture = QiraatJuncture.find_by(id: juncture_id)
      next unless juncture

      reading_ids = juncture.qiraat_readings.pluck(:id)

      QiraatReadingExplanationMembership.where(qiraat_reading_id: reading_ids).destroy_all
      QiraatReadingTranslationMembership.where(qiraat_reading_id: reading_ids).destroy_all if defined?(QiraatReadingTranslationMembership)
      QiraatReadingAttribution.where(qiraat_reading_id: reading_ids).destroy_all
      LocalizedContent.where(resource_type: 'QiraatReading', resource_id: reading_ids).destroy_all
      juncture.qiraat_readings.destroy_all
      LocalizedContent.where(resource: juncture).destroy_all
      juncture.qiraat_juncture_segments.destroy_all
      juncture.destroy
    end

    verse.verse_key
  end

  # Helper method to clear all juncture data for an entire surah (chapter)
  def self.clear_juncture_data_for_surah(chapter_id)
    verses = Verse.where(chapter_id: chapter_id)
    verse_count = 0

    verses.find_each do |verse|
      juncture_ids = QiraatJunctureSegment.where(verse_id: verse.id).pluck(:qiraat_juncture_id).uniq
      next if juncture_ids.empty?

      juncture_ids.each do |juncture_id|
        juncture = QiraatJuncture.find_by(id: juncture_id)
        next unless juncture

        reading_ids = juncture.qiraat_readings.pluck(:id)

        QiraatReadingExplanationMembership.where(qiraat_reading_id: reading_ids).destroy_all
        QiraatReadingTranslationMembership.where(qiraat_reading_id: reading_ids).destroy_all if defined?(QiraatReadingTranslationMembership)
        QiraatReadingAttribution.where(qiraat_reading_id: reading_ids).destroy_all
        LocalizedContent.where(resource_type: 'QiraatReading', resource_id: reading_ids).destroy_all
        juncture.qiraat_readings.destroy_all
        LocalizedContent.where(resource: juncture).destroy_all
        juncture.qiraat_juncture_segments.destroy_all
        juncture.destroy
      end
      verse_count += 1
    end

    verse_count
  end

  # Mapping of surah chapters to their seed task names
  SURAH_SEED_TASKS = {
    8 => 'qiraat:seed_anfal_8_65_66',
    10 => 'qiraat:seed_yunus_10_35',
    12 => 'qiraat:seed_yusuf_12_12',
    18 => 'qiraat:seed_kahf_18_96'
  }.freeze
end

namespace :qiraat do
  include QiraatSeedHelpers

  desc 'Seed all Qiraat data including readers, transmitters, and junctures'
  task seed_all: :environment do
    Rake::Task['qiraat:seed_readers'].invoke
    Rake::Task['qiraat:seed_transmitters'].invoke
    Rake::Task['qiraat:seed_yunus_10_35'].invoke
    Rake::Task['qiraat:seed_anfal_8_65_66'].invoke
    Rake::Task['qiraat:seed_yusuf_12_12'].invoke
    Rake::Task['qiraat:seed_kahf_18_96'].invoke
    puts "\n✅ All Qiraat data seeded successfully!"
  end

  desc 'Clear all Qiraat juncture data for a specific surah. Usage: rake qiraat:clear_surah[chapter_id]'
  task :clear_surah, [:chapter_id] => :environment do |_t, args|
    chapter_id = args[:chapter_id].to_i

    if chapter_id.zero?
      puts "❌ Error: Please provide a valid chapter_id. Usage: rake qiraat:clear_surah[10]"
      next
    end

    chapter = Chapter.find_by(id: chapter_id)
    unless chapter
      puts "❌ Error: Chapter with id #{chapter_id} not found."
      next
    end

    puts "\n🗑️  Clearing Qiraat data for Surah #{chapter_id} (#{chapter.name_simple})..."
    verse_count = QiraatSeedHelpers.clear_juncture_data_for_surah(chapter_id)
    puts "✅ Cleared Qiraat data from #{verse_count} verses in Surah #{chapter.name_simple}."
  end

  desc 'Clear and reseed Qiraat data for a specific surah. Usage: rake qiraat:reseed_surah[chapter_id]'
  task :reseed_surah, [:chapter_id] => :environment do |_t, args|
    chapter_id = args[:chapter_id].to_i

    if chapter_id.zero?
      puts "❌ Error: Please provide a valid chapter_id. Usage: rake qiraat:reseed_surah[10]"
      next
    end

    chapter = Chapter.find_by(id: chapter_id)
    unless chapter
      puts "❌ Error: Chapter with id #{chapter_id} not found."
      next
    end

    seed_task = QiraatSeedHelpers::SURAH_SEED_TASKS[chapter_id]
    unless seed_task
      puts "❌ Error: No seed task found for Surah #{chapter_id} (#{chapter.name_simple})."
      puts "   Available surahs with seed data: #{QiraatSeedHelpers::SURAH_SEED_TASKS.keys.join(', ')}"
      next
    end

    puts "\n🔄 Reseeding Qiraat data for Surah #{chapter_id} (#{chapter.name_simple})..."
    puts "   Step 1: Clearing existing data..."
    verse_count = QiraatSeedHelpers.clear_juncture_data_for_surah(chapter_id)
    puts "   ✓ Cleared data from #{verse_count} verses"

    puts "   Step 2: Running seed task: #{seed_task}..."
    Rake::Task[seed_task].reenable
    Rake::Task[seed_task].invoke

    puts "\n✅ Successfully reseeded Surah #{chapter.name_simple}!"
  end

  desc 'Clear ALL Qiraat juncture data from the database (keeps readers and transmitters)'
  task clear_all: :environment do
    puts "\n🗑️  Clearing ALL Qiraat juncture data..."

    # Get counts before clearing
    juncture_count = QiraatJuncture.count
    reading_count = QiraatReading.count

    if juncture_count.zero?
      puts "   No juncture data found to clear."
      next
    end

    # Clear all data
    QiraatReadingExplanationMembership.destroy_all
    QiraatReadingTranslationMembership.destroy_all if defined?(QiraatReadingTranslationMembership)
    QiraatReadingAttribution.destroy_all
    LocalizedContent.where(resource_type: 'QiraatReading').destroy_all
    LocalizedContent.where(resource_type: 'QiraatJuncture').destroy_all
    LocalizedContent.where(resource_type: 'QiraatReadingExplanation').destroy_all
    LocalizedContent.where(resource_type: 'QiraatReadingTranslation').destroy_all
    QiraatReadingExplanation.destroy_all
    QiraatReadingTranslation.destroy_all if defined?(QiraatReadingTranslation)
    QiraatReading.destroy_all
    QiraatJunctureSegment.destroy_all
    QiraatJuncture.destroy_all

    puts "✅ Cleared #{juncture_count} junctures with #{reading_count} readings."
    puts "   (Readers and transmitters preserved)"
  end

  desc 'Seed the 10 canonical Qiraat readers'
  task seed_readers: :environment do
    puts "Seeding Qiraat Readers..."

    readers_data = [
      { name: 'Ibn ʿĀmir al-Shāmī', abbreviation: 'Ibn ʿĀmir', position: 1 },
      { name: 'Ḥamzah al-Zayyāt', abbreviation: 'Ḥamzah', position: 2 },
      { name: 'Khalaf al-Bazzār', abbreviation: 'Khalaf', position: 3 },
      { name: 'al-Kisāʾī', abbreviation: 'al-Kisāʾī', position: 4 },
      { name: 'ʿĀṣim al-Kūfī', abbreviation: 'ʿĀṣim', position: 5 },
      { name: 'Abū Jaʿfar al-Madanī', abbreviation: 'Abū Jaʿfar', position: 6 },
      { name: 'Nāfiʿ al-Madanī', abbreviation: 'Nāfiʿ', position: 7 },
      { name: 'Ibn Kathīr al-Makkī', abbreviation: 'Ibn Kathīr', position: 8 },
      { name: 'Abū ʿAmr al-Baṣrī', abbreviation: 'Abū ʿAmr', position: 9 },
      { name: 'Yaʿqūb al-Ḥaḍramī', abbreviation: 'Yaʿqūb', position: 10 }
    ]

    readers_data.each do |data|
      reader = QiraatReader.find_or_create_by!(abbreviation: data[:abbreviation]) do |r|
        r.name = data[:name]
        r.position = data[:position]
      end
      puts "  ✓ #{reader.abbreviation}"
    end

    puts "✅ Seeded #{QiraatReader.count} Qiraat readers"
  end

  desc 'Seed transmitters for each reader'
  task seed_transmitters: :environment do
    puts "\nSeeding Qiraat Transmitters..."

    transmitters_data = {
      'ʿĀṣim' => [
        { name: 'Ḥafṣ', abbreviation: 'Ḥafṣ', position: 1 },
        { name: "Shuʿbah", abbreviation: "Shuʿbah", position: 2 }
      ],
      'Nāfiʿ' => [
        { name: 'Qālūn', abbreviation: 'Qālūn', position: 1 },
        { name: 'Warsh', abbreviation: 'Warsh', position: 2 }
      ],
      'Ibn Kathīr' => [
        { name: 'al-Bazzī', abbreviation: 'al-Bazzī', position: 1 },
        { name: 'Qunbul', abbreviation: 'Qunbul', position: 2 }
      ],
      'Abū ʿAmr' => [
        { name: 'al-Dūrī', abbreviation: 'al-Dūrī', position: 1 },
        { name: 'al-Sūsī', abbreviation: 'al-Sūsī', position: 2 }
      ],
      'Ibn ʿĀmir' => [
        { name: 'Hishām', abbreviation: 'Hishām', position: 1 },
        { name: 'Ibn Dhakwān', abbreviation: 'I. Dhakwān', position: 2 }
      ],
      'Ḥamzah' => [
        { name: 'Khalaf', abbreviation: 'Khalaf', position: 1 },
        { name: 'Khallād', abbreviation: 'Khallād', position: 2 }
      ],
      'al-Kisāʾī' => [
        { name: 'al-Dūrī al-Kisāʾī', abbreviation: 'Dūrī (K)', position: 1 },
        { name: 'Abū al-Ḥārith', abbreviation: 'A. Ḥārith', position: 2 }
      ],
      'Abū Jaʿfar' => [
        { name: 'Ibn Wardān', abbreviation: 'Ibn Wardān', position: 1 },
        { name: 'Ibn Jammāz', abbreviation: 'Ibn Jammāz', position: 2 }
      ],
      'Yaʿqūb' => [
        { name: 'Ruways', abbreviation: 'Ruways', position: 1 },
        { name: 'Rawḥ', abbreviation: 'Rawḥ', position: 2 }
      ],
      'Khalaf' => [
        { name: 'Isḥāq', abbreviation: 'Isḥāq', position: 1 },
        { name: 'Idrīs', abbreviation: 'Idrīs', position: 2 }
      ]
    }

    transmitters_data.each do |reader_abbr, transmitters|
      reader = QiraatReader.find_by(abbreviation: reader_abbr)
      next unless reader

      transmitters.each do |data|
        trans = QiraatTransmitter.find_or_create_by!(
          qiraat_reader: reader,
          abbreviation: data[:abbreviation]
        ) do |t|
          t.name = data[:name]
          t.position = data[:position]
        end
        puts "  ✓ #{reader.abbreviation} → #{trans.abbreviation}"
      end
    end

    puts "✅ Seeded #{QiraatTransmitter.count} transmitters"
  end

  # ==========================================================================
  # YUNUS 10:35 - لَّا يَهِدِّىٓ (lā yahiddī) variations
  # Current production data preserved here
  # ==========================================================================
  desc 'Seed Yunus 10:35 example data'
  task seed_yunus_10_35: :environment do
    puts "\nSeeding Yunus 10:35..."

    verse = Verse.find_by!(chapter_id: 10, verse_number: 35)
    puts "Found verse: #{verse.verse_key}"
    english = Language.find_by!(iso_code: 'en')
    arabic = Language.find_by!(iso_code: 'ar')

    # Find readers
    ibn_amir = QiraatReader.find_by!(abbreviation: 'Ibn ʿĀmir')
    hamzah = QiraatReader.find_by!(abbreviation: 'Ḥamzah')
    khalaf = QiraatReader.find_by!(abbreviation: 'Khalaf')
    kisai = QiraatReader.find_by!(abbreviation: 'al-Kisāʾī')
    asim = QiraatReader.find_by!(abbreviation: 'ʿĀṣim')
    abu_jafar = QiraatReader.find_by!(abbreviation: 'Abū Jaʿfar')
    nafi = QiraatReader.find_by!(abbreviation: 'Nāfiʿ')
    ibn_kathir = QiraatReader.find_by!(abbreviation: 'Ibn Kathīr')
    abu_amr = QiraatReader.find_by!(abbreviation: 'Abū ʿAmr')
    yaqub = QiraatReader.find_by!(abbreviation: 'Yaʿqūb')

    QiraatSeedHelpers.clear_juncture_data_for_verse(verse)
    puts "  ↻ Cleared existing data"

    # Create juncture with segment at words 21-22 (لَّا يَهِدِّىٓ)
    juncture = QiraatSeedHelpers.create_juncture_with_segments(
      segments: [
        { verse: verse, start_position: 21, end_position: 22 }
      ],
      position: 1
    )
    puts "  ✓ Created juncture with segment for words 21-22"

    # Reading 1: يَهِدِّي - White (ʿĀṣim, Yaʿqūb)
    reading1 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'يَهِدِّي',
      position: 1,
      color: SEED_COLORS[:white]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: asim)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: yaqub)
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'transliteration', text: 'lā yahiddī*')
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'explanation', text: '*Shuʿbah from ʿĀṣim actually has yihiddī, included here for simplification.')
    LocalizedContent.create!(resource: reading1, language: arabic, content_type: 'explanation', text: '*قرأ شعبة عن عاصم بكسر الياء (يِهِدِّي)، ولكن أُثبتت هنا للتسهيل.')
    puts "  ✓ Reading 1: يَهِدِّي (ʿĀṣim, Yaʿqūb)"

    # Reading 2: يَهَْدِّي - Green (Ibn ʿĀmir, Nāfiʿ, Ibn Kathīr, Abū ʿAmr)
    reading2 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'يَهَْدِّي',
      position: 2,
      color: SEED_COLORS[:green]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: ibn_amir)
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: nafi)
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: ibn_kathir)
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: abu_amr)
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'transliteration', text: 'lā yahaddī*')
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'explanation', text: 'NB: Some pronounced this with an overshort vowel, closer to the third reading.')
    LocalizedContent.create!(resource: reading2, language: arabic, content_type: 'explanation', text: 'تنبيه: البعض قرأها باختلاس الفتحة، مما يجعلها أقرب للقراءة الثالثة.')
    puts "  ✓ Reading 2: يَهَْدِّي (Ibn ʿĀmir, Nāfiʿ, Ibn Kathīr, Abū ʿAmr)"

    # Reading 3: يَهْدِّي - Blue (Abū Jaʿfar)
    reading3 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'يَهْدِّي',
      position: 3,
      color: SEED_COLORS[:blue]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_reader: abu_jafar)
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'transliteration', text: 'lā yahddī')
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'explanation', text: 'The above readings are various ways to realise form VIII from the same root, originally yahtadī.')
    LocalizedContent.create!(resource: reading3, language: arabic, content_type: 'explanation', text: 'القراءات أعلاه هي أوجه مختلفة لأداء وزن (افتعل) من نفس الجذر، وأصلها "يهتدي".')
    puts "  ✓ Reading 3: يَهْدِّي (Abū Jaʿfar)"

    # Reading 4: يَهْدِي - Pink (Ḥamzah, Khalaf, al-Kisāʾī)
    reading4 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'يَهْدِي',
      position: 4,
      color: SEED_COLORS[:pink]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: hamzah)
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: khalaf)
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: kisai)
    LocalizedContent.create!(resource: reading4, language: english, content_type: 'transliteration', text: 'lā yahdī')
    LocalizedContent.create!(resource: reading4, language: english, content_type: 'explanation', text: 'This reading is based on form I of the root h-d-y. It may also be another shortened form of yahtadī.')
    LocalizedContent.create!(resource: reading4, language: english, content_type: 'translation', text: '"who cannot guide, but must be led"')
    LocalizedContent.create!(resource: reading4, language: arabic, content_type: 'explanation', text: 'هذه القراءة مبنية على الوزن المجرد (فَعَلَ) من الجذر (هـ د ي). وقد تكون أيضاً صيغة مخففة أخرى من "يهتدي".')
    LocalizedContent.create!(resource: reading4, language: arabic, content_type: 'translation', text: '"لا يَهدي إلا أن يُهدى"')
    puts "  ✓ Reading 4: يَهْدِي (Ḥamzah, Khalaf, al-Kisāʾī)"

    # Combined translation for readings 1, 2, 3 (shared)
    shared_translation = QiraatReadingTranslation.create!(source: 'Scholarly consensus', position: 1)
    LocalizedContent.create!(resource: shared_translation, language: english, content_type: 'translation', text: '"who cannot go the right way unless led"')
    LocalizedContent.create!(resource: shared_translation, language: arabic, content_type: 'translation', text: '"لا يهتدي بنفسه إلا أن يهديه غيره"')
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading1, qiraat_reading_translation: shared_translation)
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading2, qiraat_reading_translation: shared_translation)
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading3, qiraat_reading_translation: shared_translation)
    puts "  ✓ Created shared translation for readings 1-3"

    # Combined explanation on juncture level
    LocalizedContent.create!(
      resource: juncture,
      language: english,
      content_type: 'combined_translation',
      text: 'Combined translation: "who cannot go the right way unless led". These readings provide complementary meanings. It is also possible that the last reading is another shortened form of yahtadī, hence the readings all mean the same [al-Mahdawi].'
    )
    LocalizedContent.create!(
      resource: juncture,
      language: arabic,
      content_type: 'combined_translation',
      text: 'الترجمة الجامعة: "لا يهتدي بنفسه إلا أن يهديه غيره". هذه القراءات تقدم معاني متكاملة. ومن المحتمل أن القراءة الأخيرة هي صيغة مخففة أخرى من "يهتدي"، وبالتالي فإن جميع القراءات تؤدي نفس المعنى [المهدوي].'
    )
    puts "  ✓ Created juncture combined explanation"

    puts "✅ Seeded Yunus 10:35 with #{juncture.qiraat_readings.count} reading variations"
  end

  # ==========================================================================
  # ANFAL 8:65-66 - Cross-verse juncture: وَإِن يَكُن...فَإِن يَكُن
  # ==========================================================================
  desc 'Seed Anfal 8:65-66 cross-verse example data'
  task seed_anfal_8_65_66: :environment do
    puts "\nSeeding Anfal 8:65-66 (cross-verse)..."

    verse65 = Verse.find_by!(chapter_id: 8, verse_number: 65)
    verse66 = Verse.find_by!(chapter_id: 8, verse_number: 66)
    puts "Found verses: #{verse65.verse_key} and #{verse66.verse_key}"
    english = Language.find_by!(iso_code: 'en')
    arabic = Language.find_by!(iso_code: 'ar')

    # Clear existing data for both verses
    QiraatSeedHelpers.clear_juncture_data_for_verse(verse65)
    QiraatSeedHelpers.clear_juncture_data_for_verse(verse66)
    puts "  ↻ Cleared existing data"

    # Create juncture with TWO segments (cross-verse)
    # Segment 1: 8:65 words 14-15 (وَإِن يَكُن)
    # Segment 2: 8:66 words 9-10 (فَإِن يَكُن)
    juncture = QiraatJuncture.create!(position: 2)

    QiraatJunctureSegment.create!(
      qiraat_juncture: juncture,
      verse: verse65,
      start_word: verse65.words.find_by!(position: 14),
      end_word: verse65.words.find_by!(position: 15),
      position: 0
    )
    QiraatJunctureSegment.create!(
      qiraat_juncture: juncture,
      verse: verse66,
      start_word: verse66.words.find_by!(position: 9),
      end_word: verse66.words.find_by!(position: 10),
      position: 1
    )
    puts "  ✓ Created juncture with 2 cross-verse segments"

    # Find readers
    hamzah = QiraatReader.find_by!(abbreviation: 'Ḥamzah')
    khalaf = QiraatReader.find_by!(abbreviation: 'Khalaf')
    kisai = QiraatReader.find_by!(abbreviation: 'al-Kisāʾī')
    asim = QiraatReader.find_by!(abbreviation: 'ʿĀṣim')
    abu_amr = QiraatReader.find_by!(abbreviation: 'Abū ʿAmr')
    yaqub = QiraatReader.find_by!(abbreviation: 'Yaʿqūb')
    ibn_amir = QiraatReader.find_by!(abbreviation: 'Ibn ʿĀmir')
    abu_jafar = QiraatReader.find_by!(abbreviation: 'Abū Jaʿfar')
    nafi = QiraatReader.find_by!(abbreviation: 'Nāfiʿ')
    ibn_kathir = QiraatReader.find_by!(abbreviation: 'Ibn Kathīr')

    # Reading 1: وَاِنْ يَّكُنْ…..فاِنْ يَّكُنْ (Ḥamzah, Khalaf, al-Kisāʾī, ʿĀṣim)
    reading1 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'وَاِنْ يَّكُنْ….. فاِنْ يَّكُنْ',
      position: 1,
      color: SEED_COLORS[:white]
    )
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'transliteration', text: 'wa-in yakun...fa-in yakun')
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: hamzah)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: khalaf)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: kisai)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: asim)
    puts "  ✓ Reading 1: وَاِنْ يَّكُنْ…..فاِنْ يَّكُنْ (Ḥamzah, Khalaf, al-Kisāʾī, ʿĀṣim)"

    # Reading 2: وَاِنْ يَكُنْ…..فاِنْ تَكُنْ (Abū ʿAmr, Yaʿqūb)
    reading2 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'وَاِنْ يَكُنْ…..فاِنْ تَكُنْ',
      position: 2,
      color: SEED_COLORS[:green]
    )
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'transliteration', text: 'wa-in yakun...fa-in takun')
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: abu_amr)
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: yaqub)
    puts "  ✓ Reading 2: وَاِنْ يَكُنْ…..فاِنْ تَكُنْ (Abū ʿAmr, Yaʿqūb)"

    # Reading 3: وَاِنْ تَكُنْ….. فَاِنْ تكُنْ (Ibn ʿĀmir, Abū Jaʿfar, Nāfiʿ, Ibn Kathīr)
    reading3 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'وَاِنْ تَكُنْ….. فَاِنْ تكُنْ',
      position: 3,
      color: SEED_COLORS[:blue]
    )
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'transliteration', text: 'wa-in takun...fa-in takun')
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_reader: ibn_amir)
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_reader: abu_jafar)
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_reader: nafi)
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_reader: ibn_kathir)
    puts "  ✓ Reading 3: وَاِنْ تَكُنْ…..فَاِنْ تكُنْ (Ibn ʿĀmir, Abū Jaʿfar, Nāfiʿ, Ibn Kathīr)"

    # Combined translation for all 3 readings (shared)
    shared_translation = QiraatReadingTranslation.create!(source: 'Scholarly consensus', position: 1)
    LocalizedContent.create!(resource: shared_translation, language: english, content_type: 'translation', text: '"and/so if there should be a hundred"')
    LocalizedContent.create!(resource: shared_translation, language: arabic, content_type: 'translation', text: '"وإن يكن / فإن يكن منكم مائة"')
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading1, qiraat_reading_translation: shared_translation)
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading2, qiraat_reading_translation: shared_translation)
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading3, qiraat_reading_translation: shared_translation)
    puts "  ✓ Created shared translation for all 3 readings"

    # Combined explanation on juncture level
    LocalizedContent.create!(
      resource: juncture,
      language: english,
      content_type: 'combined_translation',
      text: 'These readings represent linguistic options in using the feminine for the word mi\'ah (\'hundred\'), or the masculine due to its referents (male fighters). The second reading combines these options [al-Mahdawi].'
    )
    LocalizedContent.create!(
      resource: juncture,
      language: arabic,
      content_type: 'combined_translation',
      text: 'هذه القراءات تمثل وجهاً لغوياً في تأنيث لفظ "مائة"، أو تذكيرها نظراً لمرجعها (المقاتلين الرجال). القراءة الثانية تجمع بين هذين الوجهين [المهدوي].'
    )
    puts "  ✓ Created juncture combined explanation"

    puts "✅ Seeded Anfal 8:65-66 with #{juncture.qiraat_readings.count} reading variations (CROSS-VERSE)"
  end

  # ==========================================================================
  # YUSUF 12:12 - يَرتَعْ وَيَلعَبْ (yartaʿ wa-yalʿab) variations
  # ==========================================================================
  desc 'Seed Yusuf 12:12 example data'
  task seed_yusuf_12_12: :environment do
    puts "\nSeeding Yusuf 12:12..."

    verse = Verse.find_by!(chapter_id: 12, verse_number: 12)
    puts "Found verse: #{verse.verse_key}"
    english = Language.find_by!(iso_code: 'en')
    arabic = Language.find_by!(iso_code: 'ar')

    # Find readers
    ibn_amir = QiraatReader.find_by!(abbreviation: 'Ibn ʿĀmir')
    hamzah = QiraatReader.find_by!(abbreviation: 'Ḥamzah')
    khalaf = QiraatReader.find_by!(abbreviation: 'Khalaf')
    kisai = QiraatReader.find_by!(abbreviation: 'al-Kisāʾī')
    asim = QiraatReader.find_by!(abbreviation: 'ʿĀṣim')
    abu_jafar = QiraatReader.find_by!(abbreviation: 'Abū Jaʿfar')
    nafi = QiraatReader.find_by!(abbreviation: 'Nāfiʿ')
    ibn_kathir = QiraatReader.find_by!(abbreviation: 'Ibn Kathīr')
    abu_amr = QiraatReader.find_by!(abbreviation: 'Abū ʿAmr')
    yaqub = QiraatReader.find_by!(abbreviation: 'Yaʿqūb')

    QiraatSeedHelpers.clear_juncture_data_for_verse(verse)
    puts "  ↻ Cleared existing data"

    # Create juncture with segment at words 4-5
    juncture = QiraatSeedHelpers.create_juncture_with_segments(
      segments: [
        { verse: verse, start_position: 4, end_position: 5 }
      ],
      position: 1
    )
    puts "  ✓ Created juncture with segment for words 4-5"

    # Reading 1: يَرتَعْ وَيَلعَبْ - White (Ḥamzah, Khalaf, al-Kisāʾī, ʿĀṣim, Yaʿqūb)
    reading1 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'يَرتَعْ وَيَلعَبْ',
      position: 1,
      color: SEED_COLORS[:white]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: hamzah)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: khalaf)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: kisai)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: asim)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: yaqub)
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'transliteration', text: 'yartaʿ wa-yalʿab')
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'translation', text: '"so he will enjoy/eat and play"')
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'explanation', text: 'In this and the following reading, the first jussive verb is based on the root r-t-ʿ, meaning enjoyment or eating heartily. Both verbs are conjugated for the third person singular, as the brothers were referring to Joseph (pbuh).')
    LocalizedContent.create!(resource: reading1, language: arabic, content_type: 'translation', text: '"يرتع ويلعب"')
    LocalizedContent.create!(resource: reading1, language: arabic, content_type: 'explanation', text: 'في هذه القراءة والتي تليها، الفعل المجزوم الأول مشتق من الجذر (ر ت ع)، بمعنى التنعم أو الأكل برغد. كلا الفعلين بصيغة الغائب المفرد، حيث كان الإخوة يشيرون إلى يوسف (عليه السلام).')
    puts "  ✓ Reading 1: يَرتَعْ وَيَلعَبْ (Ḥamzah, Khalaf, al-Kisāʾī, ʿĀṣim, Yaʿqūb)"

    # Reading 2: نَرتَعْ وَنَلعَبْ - Green (Ibn ʿĀmir, Abū ʿAmr)
    reading2 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'نَرتَعْ وَنَلعَبْ',
      position: 2,
      color: SEED_COLORS[:green]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: ibn_amir)
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: abu_amr)
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'transliteration', text: 'nartaʿ wa-nalʿab')
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'translation', text: '"so we will enjoy/eat and play"')
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'explanation', text: 'In this reading, the verbs are conjugated for the first person plural, i.e. the brothers including Joseph.')
    LocalizedContent.create!(resource: reading2, language: arabic, content_type: 'translation', text: '"نرتع ونلعب"')
    LocalizedContent.create!(resource: reading2, language: arabic, content_type: 'explanation', text: 'في هذه القراءة، الفعلان بصيغة المتكلم الجمع، أي الإخوة ويوسف معهم.')
    puts "  ✓ Reading 2: نَرتَعْ وَنَلعَبْ (Ibn ʿĀmir, Abū ʿAmr)"

    # Reading 3: يَرْتَعِ وَيَلعَب - Blue (Abū Jaʿfar, Nāfiʿ)
    reading3 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'يَرْتَعِ وَيَلعَب',
      position: 3,
      color: SEED_COLORS[:blue]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_reader: abu_jafar)
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_reader: nafi)
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'transliteration', text: 'yartaʿi wa-yalʿab')
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'translation', text: '"so he will graze and play"')
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'explanation', text: 'In this and the following reading, the first jussive verb is based on the root r-ʿ-y, meaning to graze (as an expression for eating, or literally to send out one\'s animals to pasture). Here again, the pronouns are for Joseph.')
    LocalizedContent.create!(resource: reading3, language: arabic, content_type: 'translation', text: '"يرتع ويلعب (يرعى)"')
    LocalizedContent.create!(resource: reading3, language: arabic, content_type: 'explanation', text: 'في هذه القراءة والتي تليها، الفعل الأول مشتق من الجذر (ر ع ي)، بمعنى الرعي (ككناية عن الأكل، أو حرفياً إرسال الدواب للمرعى). وهنا أيضاً الضمائر تعود ليوسف.')
    puts "  ✓ Reading 3: يَرْتَعِ وَيَلعَب (Abū Jaʿfar, Nāfiʿ)"

    # Reading 4: نَرتَعِ وَنَلعَبْ - Pink (Ibn Kathīr)
    reading4 = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: 'نَرتَعِ وَنَلعَبْ',
      position: 4,
      color: SEED_COLORS[:pink]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: ibn_kathir)
    LocalizedContent.create!(resource: reading4, language: english, content_type: 'transliteration', text: 'nartaʿi wa-nalʿab')
    LocalizedContent.create!(resource: reading4, language: english, content_type: 'translation', text: '"so we will graze and play"')
    LocalizedContent.create!(resource: reading4, language: english, content_type: 'explanation', text: 'In this reading, the verbs are conjugated for the brothers including Joseph.')
    LocalizedContent.create!(resource: reading4, language: arabic, content_type: 'translation', text: '"نرتع ونلعب"')
    LocalizedContent.create!(resource: reading4, language: arabic, content_type: 'explanation', text: 'في هذه القراءة، الفعلان بصيغة المتكلم الجمع، أي الإخوة ويوسف معهم.')
    puts "  ✓ Reading 4: نَرتَعِ وَنَلعَبْ (Ibn Kathīr)"

    # Combined explanation on juncture level
    LocalizedContent.create!(
      resource: juncture,
      language: english,
      content_type: 'combined_translation',
      text: 'These readings provide complementary meanings [al-Mahdawi].'
    )
    LocalizedContent.create!(
      resource: juncture,
      language: arabic,
      content_type: 'combined_translation',
      text: 'هذه القراءات تقدم معاني متكاملة [المهدوي].'
    )
    puts "  ✓ Created juncture combined explanation"

    puts "✅ Seeded Yusuf 12:12 with #{juncture.qiraat_readings.count} reading variations"
  end

  # ==========================================================================
  # KAHF 18:96 - Two junctures in one verse:
  # Juncture 1: اتوني...اتوني (words 1-1 and 15-16) - give/come variations
  # Juncture 2: الصدفين (word 8-8) - mountainside pronunciation variations
  # ==========================================================================
  desc 'Seed Kahf 18:96 example data (2 junctures)'
  task seed_kahf_18_96: :environment do
    puts "\nSeeding Kahf 18:96 (2 junctures)..."

    verse = Verse.find_by!(chapter_id: 18, verse_number: 96)
    puts "Found verse: #{verse.verse_key}"
    english = Language.find_by!(iso_code: 'en')
    arabic = Language.find_by!(iso_code: 'ar')

    # Find readers
    ibn_amir = QiraatReader.find_by!(abbreviation: 'Ibn ʿĀmir')
    hamzah = QiraatReader.find_by!(abbreviation: 'Ḥamzah')
    khalaf = QiraatReader.find_by!(abbreviation: 'Khalaf')
    kisai = QiraatReader.find_by!(abbreviation: 'al-Kisāʾī')
    asim = QiraatReader.find_by!(abbreviation: 'ʿĀṣim')
    abu_jafar = QiraatReader.find_by!(abbreviation: 'Abū Jaʿfar')
    nafi = QiraatReader.find_by!(abbreviation: 'Nāfiʿ')
    ibn_kathir = QiraatReader.find_by!(abbreviation: 'Ibn Kathīr')
    abu_amr = QiraatReader.find_by!(abbreviation: 'Abū ʿAmr')
    yaqub = QiraatReader.find_by!(abbreviation: 'Yaʿqūb')

    # Find transmitters
    hafs = QiraatTransmitter.find_by!(abbreviation: 'Ḥafṣ')
    shubah = QiraatTransmitter.find_by!(abbreviation: "Shuʿbah")

    QiraatSeedHelpers.clear_juncture_data_for_verse(verse)
    puts "  ↻ Cleared existing data"

    # ==========================================================================
    # JUNCTURE 1: اتوني...اتوني (words 1-1 and 15-16)
    # ==========================================================================
    juncture1 = QiraatJuncture.create!(position: 1)

    # Segment 1: word 1-1 (اتوني)
    QiraatJunctureSegment.create!(
      qiraat_juncture: juncture1,
      verse: verse,
      start_word: verse.words.find_by!(position: 1),
      end_word: verse.words.find_by!(position: 1),
      position: 0
    )
    # Segment 2: words 15-16 (قال اتوني)
    QiraatJunctureSegment.create!(
      qiraat_juncture: juncture1,
      verse: verse,
      start_word: verse.words.find_by!(position: 15),
      end_word: verse.words.find_by!(position: 16),
      position: 1
    )
    puts "  ✓ Created juncture 1 with 2 segments (words 1-1, 15-16)"

    # Reading 1: ءَاتُونِي...قَالَ ءَاتُونِي - White (majority)
    # Ḥafṣ (transmitter), Khalaf, al-Kisāʾī, ʿĀṣim, Abū Jaʿfar, Nāfiʿ, Ibn Kathīr, Abū ʿAmr, Yaʿqūb, Ibn ʿĀmir
    reading1 = QiraatReading.create!(
      qiraat_juncture: juncture1,
      text_uthmani: 'ءَاتُونِي...قَالَ ءَاتُونِي',
      position: 1,
      color: SEED_COLORS[:white]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_transmitter: hafs) # Transmitter-level for Ḥafṣ
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: khalaf)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: kisai)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: asim)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: abu_jafar)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: nafi)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: ibn_kathir)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: abu_amr)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: yaqub)
    QiraatReadingAttribution.create!(qiraat_reading: reading1, qiraat_reader: ibn_amir)
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'transliteration', text: 'ātūnī...qāla ātūnī')
    LocalizedContent.create!(resource: reading1, language: english, content_type: 'translation', text: '"give me iron blocks...give me copper to pour"')
    LocalizedContent.create!(resource: reading1, language: arabic, content_type: 'translation', text: '"آتوني زبر الحديد... آتوني أفرغ عليه قطرا"')
    # Shared explanation for reading 1
    exp1 = QiraatReadingExplanation.create!(source: 'Scholarly consensus', position: 1)
    LocalizedContent.create!(resource: exp1, language: english, content_type: 'explanation', text: "In this reading, both occurrences of the verbs are form IV, 'give'.")
    LocalizedContent.create!(resource: exp1, language: arabic, content_type: 'explanation', text: "في هذه القراءة، كلا الفعلين من الوزن الرابع (أفعل)، بمعنى 'أعطى'.")
    QiraatReadingExplanationMembership.create!(qiraat_reading: reading1, qiraat_reading_explanation: exp1)
    puts "  ✓ Reading 1: ءَاتُونِي...قَالَ ءَاتُونِي (majority)"

    # Reading 2: ءَاتُونِي...قَالَ ائْتُونِي - Green (Ḥamzah only)
    reading2 = QiraatReading.create!(
      qiraat_juncture: juncture1,
      text_uthmani: 'ءَاتُونِي...قَالَ ائْتُونِي',
      position: 2,
      color: SEED_COLORS[:green]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading2, qiraat_reader: hamzah)
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'transliteration', text: 'ātūnī...qāla ʾtūnī')
    LocalizedContent.create!(resource: reading2, language: english, content_type: 'translation', text: '"give me iron blocks...come to (help) me as I pour copper"')
    LocalizedContent.create!(resource: reading2, language: arabic, content_type: 'translation', text: '"آتوني زبر الحديد... ائتوني أفرغ عليه قطرا (تعالوا إلي)"')
    # Shared explanation for reading 2
    exp2 = QiraatReadingExplanation.create!(source: 'Scholarly consensus', position: 1)
    LocalizedContent.create!(resource: exp2, language: english, content_type: 'explanation', text: "In this reading, the first verb is form IV, 'give', and the second is form I, 'come' (hence the object qiṭran is acted upon only by the verb ufrigh).")
    LocalizedContent.create!(resource: exp2, language: arabic, content_type: 'explanation', text: "في هذه القراءة، الفعل الأول من الوزن الرابع (أعطى)، والثاني من الوزن الأول (أتى/جاء) (وبذلك فإن المفعول به 'قطراً' يتعلق فقط بالفعل 'أفرغ').")
    QiraatReadingExplanationMembership.create!(qiraat_reading: reading2, qiraat_reading_explanation: exp2)
    puts "  ✓ Reading 2: ءَاتُونِي...قَالَ ائْتُونِي (Ḥamzah)"

    # Reading 3: ائْتُونِي...قَالَ ائْتُونِي - Blue (Shuʿbah only)
    reading3 = QiraatReading.create!(
      qiraat_juncture: juncture1,
      text_uthmani: 'ائْتُونِي...قَالَ ائْتُونِي',
      position: 3,
      color: SEED_COLORS[:blue]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading3, qiraat_transmitter: shubah) # Transmitter-level for Shuʿbah
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'transliteration', text: 'ītūnī...qāla ʾtūnī*')
    LocalizedContent.create!(resource: reading3, language: english, content_type: 'translation', text: '"bring me iron blocks...bring me copper to pour"')
    LocalizedContent.create!(resource: reading3, language: arabic, content_type: 'translation', text: '"ائتوني زبر الحديد (جيئو بي)... ائتوني أفرغ عليه قطرا"')
    # Shared explanation for reading 3
    exp3 = QiraatReadingExplanation.create!(source: 'Scholarly consensus', position: 1)
    LocalizedContent.create!(resource: exp3, language: english, content_type: 'explanation', text: "In this reading, both occurrences of the verbs are form I, 'come', but there is an implied ba' particle, hence it means 'bring'. *When joining to the previous verse, this is pronounced radman-iʾtūnī. Another narration from Shuʿbah has the second word as ātūnī, hence 'come...give/bring'.")
    LocalizedContent.create!(resource: exp3, language: arabic, content_type: 'explanation', text: "في هذه القراءة، كلا الفعلين من الوزن الأول (أتى)، ولكن بتضمين معنى الباء، فتفيد معنى 'جيئوني بـ'... *عند الوصل بالآية السابقة، تُلفظ 'ردماً ائتوني'. وهناك رواية أخرى عن شعبة بلفظ 'آتوني' للكلمة الثانية، أي 'ائتوني...أعطوني/جيئوني بـ'.")
    QiraatReadingExplanationMembership.create!(qiraat_reading: reading3, qiraat_reading_explanation: exp3)
    puts "  ✓ Reading 3: ائْتُونِي...قَالَ ائْتُونِي (Shuʿbah)"

    # Combined explanation for juncture 1
    LocalizedContent.create!(
      resource: juncture1,
      language: english,
      content_type: 'combined_translation',
      text: 'These readings amount to the same meaning [al-Alusi].'
    )
    LocalizedContent.create!(
      resource: juncture1,
      language: arabic,
      content_type: 'combined_translation',
      text: 'هذه القراءات تؤول إلى نفس المعنى [الألوسي].'
    )
    puts "  ✓ Created juncture 1 combined explanation"

    # ==========================================================================
    # JUNCTURE 2: الصدفين (word 8-8)
    # ==========================================================================
    juncture2 = QiraatJuncture.create!(position: 2)

    QiraatJunctureSegment.create!(
      qiraat_juncture: juncture2,
      verse: verse,
      start_word: verse.words.find_by!(position: 8),
      end_word: verse.words.find_by!(position: 8),
      position: 0
    )
    puts "  ✓ Created juncture 2 with 1 segment (word 8-8)"

    # Reading 1: الصَّدَفَيْنِ - White (Ḥamzah, Khalaf, al-Kisāʾī, Abū Jaʿfar, Nāfiʿ, Ḥafṣ)
    reading4 = QiraatReading.create!(
      qiraat_juncture: juncture2,
      text_uthmani: 'الصَّدَفَيْنِ',
      position: 1,
      color: SEED_COLORS[:white]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: hamzah)
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: khalaf)
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: kisai)
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: abu_jafar)
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_reader: nafi)
    QiraatReadingAttribution.create!(qiraat_reading: reading4, qiraat_transmitter: hafs) # Transmitter-level for Ḥafṣ
    LocalizedContent.create!(resource: reading4, language: english, content_type: 'transliteration', text: 'bayna ṣ-ṣadafayni')
    puts "  ✓ Reading 1: الصَّدَفَيْنِ (Ḥamzah, Khalaf, al-Kisāʾī, Abū Jaʿfar, Nāfiʿ, Ḥafṣ)"

    # Reading 2: الصُّدُفَيْنِ - Green (Ibn ʿĀmir, Ibn Kathīr, Abū ʿAmr, Yaʿqūb)
    reading5 = QiraatReading.create!(
      qiraat_juncture: juncture2,
      text_uthmani: 'الصُّدُفَيْنِ',
      position: 2,
      color: SEED_COLORS[:green]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading5, qiraat_reader: ibn_amir)
    QiraatReadingAttribution.create!(qiraat_reading: reading5, qiraat_reader: ibn_kathir)
    QiraatReadingAttribution.create!(qiraat_reading: reading5, qiraat_reader: abu_amr)
    QiraatReadingAttribution.create!(qiraat_reading: reading5, qiraat_reader: yaqub)
    LocalizedContent.create!(resource: reading5, language: english, content_type: 'transliteration', text: 'bayna ṣ-ṣudufayni')
    puts "  ✓ Reading 2: الصُّدُفَيْنِ (Ibn ʿĀmir, Ibn Kathīr, Abū ʿAmr, Yaʿqūb)"

    # Reading 3: الصُّدْفَيْنِ - Blue (Shuʿbah only)
    reading6 = QiraatReading.create!(
      qiraat_juncture: juncture2,
      text_uthmani: 'الصُّدْفَيْنِ',
      position: 3,
      color: SEED_COLORS[:blue]
    )
    QiraatReadingAttribution.create!(qiraat_reading: reading6, qiraat_transmitter: shubah) # Transmitter-level for Shuʿbah
    LocalizedContent.create!(resource: reading6, language: english, content_type: 'transliteration', text: 'bayna ṣ-ṣudfayni')
    puts "  ✓ Reading 3: الصُّدْفَيْنِ (Shuʿbah)"

    # Shared translation for all 3 readings in juncture 2
    shared_translation = QiraatReadingTranslation.create!(source: 'Scholarly consensus', position: 1)
    LocalizedContent.create!(resource: shared_translation, language: english, content_type: 'translation', text: '"between the two mountainsides"')
    LocalizedContent.create!(resource: shared_translation, language: arabic, content_type: 'translation', text: '"بين الصدفين (الجبلين)"')
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading4, qiraat_reading_translation: shared_translation)
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading5, qiraat_reading_translation: shared_translation)
    QiraatReadingTranslationMembership.create!(qiraat_reading: reading6, qiraat_reading_translation: shared_translation)
    puts "  ✓ Created shared translation for all 3 readings"

    # Combined explanation for juncture 2
    LocalizedContent.create!(
      resource: juncture2,
      language: english,
      content_type: 'combined_translation',
      text: 'These readings represent linguistic options for this word and are identical in meaning [al-Mahdawi].'
    )
    LocalizedContent.create!(
      resource: juncture2,
      language: arabic,
      content_type: 'combined_translation',
      text: 'هذه القراءات تمثل أوجهاً لغوية لهذه الكلمة وهي متطابقة في المعنى [المهدوي].'
    )
    puts "  ✓ Created juncture 2 combined explanation"

    puts "✅ Seeded Kahf 18:96 with 2 junctures (#{juncture1.qiraat_readings.count} + #{juncture2.qiraat_readings.count} reading variations)"
  end
end

