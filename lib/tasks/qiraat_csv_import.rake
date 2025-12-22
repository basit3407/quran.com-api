# frozen_string_literal: true

require 'csv'

# CSV Importer for Qiraat "Fact Files" format
# Fully dynamic - no hardcoded mappings. Uses database lookups for word positions
# and parses reader attributions from the CSV header matrix.

namespace :qiraat do
  desc 'Import Qiraat data from a CSV file'
  task :import_csv, [:file_path] => :environment do |_t, args|
    unless args[:file_path]
      puts "Usage: rake qiraat:import_csv[/path/to/file.csv]"
      exit 1
    end

    importer = QiraatCsvImporter.new(args[:file_path])
    importer.import!
  end

  desc 'Clear all Qiraat juncture data'
  task clear_junctures: :environment do
    puts "Clearing all Qiraat juncture data..."
    QiraatReadingExplanationMembership.destroy_all
    QiraatReadingTranslationMembership.destroy_all
    QiraatReadingAttribution.destroy_all
    LocalizedContent.where(resource_type: %w[QiraatReading QiraatJuncture QiraatReadingExplanation QiraatReadingTranslation]).destroy_all
    QiraatReadingExplanation.destroy_all
    QiraatReadingTranslation.destroy_all
    QiraatReading.destroy_all
    QiraatJunctureSegment.destroy_all
    QiraatJuncture.destroy_all
    puts "✅ All juncture data cleared!"
  end
end

class QiraatCsvImporter
  SEED_COLORS = {
    1 => '#FFFFFF',   # white
    2 => '#B7D7A8',   # green
    3 => '#A4C2F4',   # blue
    4 => '#ea9999'    # pink
  }.freeze

  SURAH_MAP = {
    # 1-10
    'Fatiha' => 1, 'Al-Fatiha' => 1, 'Al-Fatihah' => 1,
    'Baqara' => 2, 'Al-Baqara' => 2, 'Al-Baqarah' => 2, 'Baqarah' => 2,
    'Ali-Imran' => 3, 'Aal-Imran' => 3, 'Al-Imran' => 3, 'Imran' => 3,
    'Nisa' => 4, 'An-Nisa' => 4, "An-Nisa'" => 4, 'Nisaa' => 4,
    'Maidah' => 5, 'Al-Maidah' => 5, "Al-Ma'idah" => 5, "Ma'idah" => 5,
    'Anam' => 6, 'Al-Anam' => 6, "Al-An'am" => 6, "An'am" => 6,
    'Araf' => 7, 'Al-Araf' => 7, "Al-A'raf" => 7, "A'raf" => 7,
    'Anfal' => 8, 'Al-Anfal' => 8,
    'Tawba' => 9, 'At-Tawba' => 9, 'At-Tawbah' => 9, 'Tawbah' => 9, 'Bara' => 9,
    'Yunus' => 10,
    # 11-20
    'Hud' => 11,
    'Yusuf' => 12,
    "Ra'ad" => 13, 'Raad' => 13, 'Ar-Raad' => 13, "Ar-Ra'd" => 13,
    'Ibrahim' => 14,
    'Hijr' => 15, 'Al-Hijr' => 15,
    'Nahl' => 16, 'An-Nahl' => 16,
    'Isra' => 17, 'Al-Isra' => 17, "Al-Isra'" => 17, 'Bani Israil' => 17,
    'Kahf' => 18, 'Al-Kahf' => 18,
    'Maryam' => 19,
    'Taha' => 20, 'Ta-Ha' => 20,
    # 21-30
    'Anbiya' => 21, 'Al-Anbiya' => 21, "Al-Anbiya'" => 21,
    'Hajj' => 22, 'Al-Hajj' => 22,
    'Muminun' => 23, 'Al-Muminun' => 23, "Al-Mu'minun" => 23,
    'Nur' => 24, 'An-Nur' => 24,
    'Furqan' => 25, 'Al-Furqan' => 25,
    'Shuara' => 26, 'Ash-Shuara' => 26, "Ash-Shu'ara'" => 26,
    'Naml' => 27, 'An-Naml' => 27,
    'Qasas' => 28, 'Al-Qasas' => 28,
    'Ankabut' => 29, 'Al-Ankabut' => 29,
    'Rum' => 30, 'Ar-Rum' => 30,
    # 31-40
    'Luqman' => 31,
    'Sajda' => 32, 'As-Sajda' => 32, 'As-Sajdah' => 32,
    'Ahzab' => 33, 'Al-Ahzab' => 33,
    'Saba' => 34, "Saba'" => 34,
    'Fatir' => 35,
    'Ya-Sin' => 36, 'Yasin' => 36, 'Yaseen' => 36,
    'Saffat' => 37, 'As-Saffat' => 37,
    'Sad' => 38,
    'Zumar' => 39, 'Az-Zumar' => 39,
    'Ghafir' => 40, 'Mumin' => 40, 'Al-Mumin' => 40,
    # 41-50
    'Fussilat' => 41, 'Ha-Mim' => 41,
    'Shura' => 42, 'Ash-Shura' => 42,
    'Zukhruf' => 43, 'Az-Zukhruf' => 43,
    'Dukhan' => 44, 'Ad-Dukhan' => 44,
    'Jathiya' => 45, 'Al-Jathiya' => 45, 'Al-Jathiyah' => 45,
    'Ahqaf' => 46, 'Al-Ahqaf' => 46,
    'Muhammad' => 47,
    'Fath' => 48, 'Al-Fath' => 48,
    'Hujurat' => 49, 'Al-Hujurat' => 49,
    'Qaf' => 50,
    # 51-60
    'Dhariyat' => 51, 'Adh-Dhariyat' => 51,
    'Tur' => 52, 'At-Tur' => 52,
    'Najm' => 53, 'An-Najm' => 53,
    'Qamar' => 54, 'Al-Qamar' => 54,
    'Rahman' => 55, 'Ar-Rahman' => 55,
    'Waqia' => 56, 'Al-Waqia' => 56, "Al-Waqi'ah" => 56,
    'Hadid' => 57, 'Al-Hadid' => 57,
    'Mujadila' => 58, 'Al-Mujadila' => 58, 'Al-Mujadilah' => 58,
    'Hashr' => 59, 'Al-Hashr' => 59,
    'Mumtahana' => 60, 'Al-Mumtahana' => 60, 'Al-Mumtahanah' => 60,
    # 61-70
    'Saff' => 61, 'As-Saff' => 61,
    'Jumua' => 62, 'Al-Jumua' => 62, "Al-Jumu'ah" => 62,
    'Munafiqun' => 63, 'Al-Munafiqun' => 63,
    'Taghabun' => 64, 'At-Taghabun' => 64,
    'Talaq' => 65, 'At-Talaq' => 65,
    'Tahrim' => 66, 'At-Tahrim' => 66,
    'Mulk' => 67, 'Al-Mulk' => 67,
    'Qalam' => 68, 'Al-Qalam' => 68, 'Nun' => 68,
    'Haqqa' => 69, 'Al-Haqqa' => 69, 'Al-Haqqah' => 69,
    'Maarij' => 70, 'Al-Maarij' => 70, "Al-Ma'arij" => 70,
    # 71-80
    'Nuh' => 71,
    'Jinn' => 72, 'Al-Jinn' => 72,
    'Muzzammil' => 73, 'Al-Muzzammil' => 73,
    'Muddaththir' => 74, 'Al-Muddaththir' => 74, 'Muddathir' => 74,
    'Qiyama' => 75, 'Al-Qiyama' => 75, 'Al-Qiyamah' => 75,
    'Insan' => 76, 'Al-Insan' => 76, 'Dahr' => 76,
    'Mursalat' => 77, 'Al-Mursalat' => 77,
    'Naba' => 78, 'An-Naba' => 78, "An-Naba'" => 78,
    'Naziat' => 79, 'An-Naziat' => 79, "An-Nazi'at" => 79,
    'Abasa' => 80,
    # 81-90
    'Takwir' => 81, 'At-Takwir' => 81,
    'Infitar' => 82, 'Al-Infitar' => 82,
    'Mutaffifin' => 83, 'Al-Mutaffifin' => 83,
    'Inshiqaq' => 84, 'Al-Inshiqaq' => 84,
    'Buruj' => 85, 'Al-Buruj' => 85,
    'Tariq' => 86, 'At-Tariq' => 86,
    'Ala' => 87, 'Al-Ala' => 87, "Al-A'la" => 87,
    'Ghashiya' => 88, 'Al-Ghashiya' => 88, 'Al-Ghashiyah' => 88,
    'Fajr' => 89, 'Al-Fajr' => 89,
    'Balad' => 90, 'Al-Balad' => 90,
    # 91-100
    'Shams' => 91, 'Ash-Shams' => 91,
    'Layl' => 92, 'Al-Layl' => 92,
    'Duha' => 93, 'Ad-Duha' => 93,
    'Sharh' => 94, 'Ash-Sharh' => 94, 'Inshirah' => 94,
    'Tin' => 95, 'At-Tin' => 95,
    'Alaq' => 96, 'Al-Alaq' => 96,
    'Qadr' => 97, 'Al-Qadr' => 97,
    'Bayyina' => 98, 'Al-Bayyina' => 98, 'Al-Bayyinah' => 98,
    'Zalzala' => 99, 'Az-Zalzala' => 99, 'Az-Zalzalah' => 99,
    'Adiyat' => 100, 'Al-Adiyat' => 100,
    # 101-110
    'Qaria' => 101, 'Al-Qaria' => 101, "Al-Qari'ah" => 101,
    'Takathur' => 102, 'At-Takathur' => 102,
    'Asr' => 103, 'Al-Asr' => 103,
    'Humaza' => 104, 'Al-Humaza' => 104, 'Al-Humazah' => 104,
    'Fil' => 105, 'Al-Fil' => 105,
    'Quraysh' => 106, 'Quraish' => 106,
    'Maun' => 107, 'Al-Maun' => 107, "Al-Ma'un" => 107,
    'Kawthar' => 108, 'Al-Kawthar' => 108, 'Kauthar' => 108,
    'Kafirun' => 109, 'Al-Kafirun' => 109,
    'Nasr' => 110, 'An-Nasr' => 110,
    # 111-114
    'Masad' => 111, 'Al-Masad' => 111, 'Lahab' => 111,
    'Ikhlas' => 112, 'Al-Ikhlas' => 112,
    'Falaq' => 113, 'Al-Falaq' => 113,
    'Nas' => 114, 'An-Nas' => 114
  }.freeze

  # All known reader abbreviations for detection
  READER_ABBREVIATIONS = [
    'Ibn ʿĀmir', 'Ḥamzah', 'Khalaf', 'al-Kisāʾī', 'ʿĀṣim',
    'Abū Jaʿfar', 'Nāfiʿ', 'Ibn Kathīr', 'Abū ʿAmr', 'Yaʿqūb'
  ].freeze

  TRANSMITTER_ABBREVIATIONS = ['Shuʿbah', 'Ḥafṣ', 'al-Bazzī', 'Qunbul', 'Qālūn', 'Warsh'].freeze

  def initialize(file_path)
    @file_path = file_path
    @english = Language.find_by!(iso_code: 'en')
    @readers = QiraatReader.all.index_by(&:abbreviation)
    @transmitters = QiraatTransmitter.all.index_by(&:abbreviation)
    @juncture_position = 0
    @cleared_verses = Set.new
  end

  def import!
    puts "Importing from: #{@file_path}"
    puts ""

    content = File.read(@file_path, encoding: 'UTF-8')

    # Parse entire CSV properly (handles multi-line quoted fields)
    all_rows = CSV.parse(content, liberal_parsing: true)

    blocks = split_into_blocks_from_rows(all_rows)
    puts "Found #{blocks.count} juncture block(s)"
    puts ""

    blocks.each do |block|
      import_block_from_rows(block)
    end

    puts ""
    puts "✅ Import complete!"
    puts "   Junctures: #{QiraatJuncture.count}"
    puts "   Readings: #{QiraatReading.count}"
    puts "   Segments: #{QiraatJunctureSegment.count}"
  end

  private

  def split_into_blocks_from_rows(rows)
    blocks = []
    current_block = []

    rows.each do |row|
      first_cell = row&.[](0)&.to_s&.strip || ''

      if juncture_header?(first_cell)
        blocks << current_block if current_block.any?
        current_block = [row]
      else
        current_block << row
      end
    end

    blocks << current_block if current_block.any?
    blocks.reject(&:empty?)
  end

  def juncture_header?(cell)
    return false if cell.nil? || cell.to_s.strip.empty?
    SURAH_MAP.keys.any? { |name| cell.to_s.start_with?(name) }
  end

  def import_block_from_rows(rows)
    return if rows.empty?

    first_row = rows[0]
    header = first_row[0]&.to_s&.strip
    return unless header

    # Get base text (juncture identifier) from the second row
    second_row = rows[1] if rows.length > 1
    base_text = second_row&.[](0)&.to_s&.strip || ''

    puts "=" * 60
    puts "Importing: #{header}"
    puts "  Base text: #{base_text}" if base_text.present?
    puts "=" * 60

    juncture_info = parse_header(header)
    return unless juncture_info

    juncture_info[:base_text] = base_text

    # Find verses
    verses = juncture_info[:verses].filter_map do |v|
      Verse.find_by(chapter_id: juncture_info[:chapter_id], verse_number: v)
    end

    if verses.empty?
      puts "  ⚠️  Could not find verses, skipping"
      return
    end

    puts "  Found verse(s): #{verses.map(&:verse_key).join(', ')}"

    # Parse readings from the block (using pre-parsed rows)
    readings_data = parse_readings_from_rows(rows)
    puts "  Found #{readings_data.count} reading(s)"

    return if readings_data.empty?

    # Parse reader attribution matrix from header rows
    attribution_matrix = parse_attribution_matrix_from_rows(rows)

    # DYNAMIC: Find word positions by searching for the base text in the verse
    word_positions = find_word_positions(verses, base_text, readings_data)
    if word_positions.nil? || word_positions.empty?
      puts "  ⚠️  Could not find word positions for '#{base_text}', skipping"
      return
    end
    puts "  Found word positions: #{word_positions.map { |wp| "#{wp[:verse]}:#{wp[:start]}-#{wp[:end]}" }.join(', ')}"

    # Only clear verse data ONCE per verse
    verse_key = "#{juncture_info[:chapter_id]}:#{juncture_info[:verses].join('-')}:#{base_text}"
    unless @cleared_verses.include?(verse_key)
      @cleared_verses.add(verse_key)
    end

    # Create juncture
    @juncture_position += 1
    juncture = QiraatJuncture.create!(position: @juncture_position)

    # Create segments
    word_positions.each_with_index do |wp, idx|
      verse = Verse.find_by!(chapter_id: juncture_info[:chapter_id], verse_number: wp[:verse])
      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: verse.words.find_by!(position: wp[:start]),
        end_word: verse.words.find_by!(position: wp[:end]),
        position: idx
      )
    end
    puts "  ✓ Created #{word_positions.count} segment(s)"

    # Create readings (returns array of created readings with their translation info)
    created_readings = []
    readings_data.each_with_index do |rd, idx|
      reading = create_reading(juncture, rd, idx + 1, juncture_info, attribution_matrix, verses)
      created_readings << { reading: reading, data: rd }
    end

    # Handle shared translations
    handle_shared_translations(created_readings)

    # Parse and add combined explanation
    combined = parse_combined_explanation_from_rows(rows)
    if combined
      LocalizedContent.create!(
        resource: juncture,
        language: @english,
        content_type: 'combined_translation',
        text: combined
      )
      puts "  ✓ Added combined explanation"
    end

    puts "✅ Imported #{header} with #{readings_data.count} readings"
  end

  def parse_readings_from_rows(rows)
    readings = []

    rows.each do |row|
      next if row.nil?

      first_cell = row[0]&.to_s&.strip || ''
      second_cell = row[1]&.to_s&.strip || ''
      fourth_cell = row[3]&.to_s&.strip || ''

      # A reading row has: empty first cell, Arabic in second, transliteration in fourth
      next unless first_cell.empty?
      next unless second_cell.match?(/[\u0600-\u06FF]/)
      next unless fourth_cell.present? && fourth_cell.match?(/[a-zA-Z]/)

      translation = row[7]&.to_s&.strip || ''
      translation = translation.gsub(/^"|"$/, '').gsub('""', '"').gsub(/^""|""$/, '"')

      readings << {
        arabic: second_cell,
        transliteration: fourth_cell,
        translation: translation.presence
      }
    end

    attach_explanations_from_rows(readings, rows)
    readings
  end

  def attach_explanations_from_rows(readings, rows)
    reading_idx = 0
    rows.each do |row|
      next if row.nil?

      first_cell = row[0]&.to_s&.strip || ''
      second_cell = row[1]&.to_s&.strip || ''
      fourth_cell = row[3]&.to_s&.strip || ''

      # Reading row - move to next reading
      if first_cell.empty? && second_cell.match?(/[\u0600-\u06FF]/) && fourth_cell.present? && fourth_cell.match?(/[a-zA-Z]/)
        reading_idx = readings.index { |r| r[:arabic] == second_cell }
        reading_idx = (reading_idx || -1) + 1
        next
      end

      # Explanation row
      if first_cell.empty? && second_cell.present? &&
         !second_cell.match?(/[\u0600-\u06FF]/) &&
         (fourth_cell.nil? || fourth_cell.empty?) &&
         !combined_explanation?(second_cell) &&
         reading_idx > 0 && reading_idx <= readings.length

        reading = readings[reading_idx - 1]
        reading[:explanation] ||= ''
        reading[:explanation] += ' ' unless reading[:explanation].empty?
        reading[:explanation] += second_cell
      end
    end
  end

  def parse_attribution_matrix_from_rows(rows)
    matrix = { readers: [], transmitters: [], split_readers: [] }

    rows[0..4].each do |row|
      next if row.nil?

      row.each_with_index do |cell, idx|
        next if cell.nil?
        cell_str = cell.to_s.strip

        if READER_ABBREVIATIONS.include?(cell_str)
          matrix[:readers] << { name: cell_str, column: idx }
        elsif TRANSMITTER_ABBREVIATIONS.include?(cell_str)
          matrix[:transmitters] << { name: cell_str, column: idx }
          parent_col = matrix[:readers].select { |r| r[:column] <= idx }.max_by { |r| r[:column] }
          if parent_col
            matrix[:split_readers] << parent_col[:name] unless matrix[:split_readers].include?(parent_col[:name])
          end
        end
      end
    end

    matrix
  end

  def parse_combined_explanation_from_rows(rows)
    rows.each do |row|
      next if row.nil?
      second_cell = row[1]&.to_s&.strip || ''
      return second_cell if combined_explanation?(second_cell)
    end
    nil
  end

  def import_block(lines)
    return if lines.empty?

    first_row = CSV.parse_line(lines[0]) rescue []
    header = first_row[0]&.strip
    return unless header

    # Get base text (juncture identifier) from the header row or second row
    second_row = CSV.parse_line(lines[1]) rescue [] if lines.length > 1
    base_text = second_row&.[](0)&.strip || ''

    puts "=" * 60
    puts "Importing: #{header}"
    puts "  Base text: #{base_text}" if base_text.present?
    puts "=" * 60

    juncture_info = parse_header(header)
    return unless juncture_info

    juncture_info[:base_text] = base_text

    # Find verses
    verses = juncture_info[:verses].filter_map do |v|
      Verse.find_by(chapter_id: juncture_info[:chapter_id], verse_number: v)
    end

    if verses.empty?
      puts "  ⚠️  Could not find verses, skipping"
      return
    end

    puts "  Found verse(s): #{verses.map(&:verse_key).join(', ')}"

    # Parse readings from the block
    readings_data = parse_readings(lines)
    puts "  Found #{readings_data.count} reading(s)"

    return if readings_data.empty?

    # Parse reader attribution matrix from header rows
    attribution_matrix = parse_attribution_matrix(lines)
    puts "  Attribution matrix: #{attribution_matrix.inspect}" if attribution_matrix.any?

    # DYNAMIC: Find word positions by searching for the base text in the verse
    word_positions = find_word_positions(verses, base_text, readings_data)
    if word_positions.nil? || word_positions.empty?
      puts "  ⚠️  Could not find word positions for '#{base_text}', skipping"
      return
    end
    puts "  Found word positions: #{word_positions.map { |wp| "#{wp[:verse]}:#{wp[:start]}-#{wp[:end]}" }.join(', ')}"

    # Only clear verse data ONCE per verse
    verse_key = "#{juncture_info[:chapter_id]}:#{juncture_info[:verses].join('-')}:#{base_text}"
    unless @cleared_verses.include?(verse_key)
      # Don't clear - we'll create new junctures alongside existing ones
      @cleared_verses.add(verse_key)
    end

    # Create juncture
    @juncture_position += 1
    juncture = QiraatJuncture.create!(position: @juncture_position)

    # Create segments
    word_positions.each_with_index do |wp, idx|
      verse = Verse.find_by!(chapter_id: juncture_info[:chapter_id], verse_number: wp[:verse])
      QiraatJunctureSegment.create!(
        qiraat_juncture: juncture,
        verse: verse,
        start_word: verse.words.find_by!(position: wp[:start]),
        end_word: verse.words.find_by!(position: wp[:end]),
        position: idx
      )
    end
    puts "  ✓ Created #{word_positions.count} segment(s)"

    # Create readings (returns array of created readings with their translation info)
    created_readings = []
    readings_data.each_with_index do |rd, idx|
      reading = create_reading(juncture, rd, idx + 1, juncture_info, attribution_matrix, verses)
      created_readings << { reading: reading, data: rd }
    end

    # Handle shared translations
    # Pattern: readings WITHOUT translations share the first available translation
    # Readings WITH their own translation keep individual translations
    handle_shared_translations(created_readings)

    # Parse and add combined explanation
    combined = parse_combined_explanation(lines)
    if combined
      LocalizedContent.create!(
        resource: juncture,
        language: @english,
        content_type: 'combined_translation',
        text: combined
      )
      puts "  ✓ Added combined explanation"
    end

    puts "✅ Imported #{header} with #{readings_data.count} readings"
  end

  def handle_shared_translations(created_readings)
    # Pattern: readings WITHOUT translation share with the IMMEDIATELY PRECEDING
    # reading that HAS a translation.
    #
    # Example for Hijr 8:
    #   R1: "We only send down..." -> individual
    #   R2: "The angels are only sent down..." -> individual
    #   R3: "The angels only come down..." -> source for R4's shared translation
    #   R4: (no translation) -> shares with R3
    #
    # Example for Yunus 35:
    #   R1: "who cannot go the right way..." -> source for R2, R3
    #   R2: (no translation) -> shares with R1
    #   R3: (no translation) -> shares with R1
    #   R4: "who cannot guide, but must be led" -> individual

    # Group readings by which translation they share
    # Key = index of the reading that provides the translation, Value = array of readings sharing it
    translation_groups = {}
    last_translation_idx = nil

    created_readings.each_with_index do |cr, idx|
      if cr[:data][:translation].present?
        # This reading has its own translation - it becomes the source for subsequent ones
        last_translation_idx = idx
      elsif last_translation_idx
        # This reading needs to share with the previous translation source
        translation_groups[last_translation_idx] ||= []
        translation_groups[last_translation_idx] << cr
      end
    end

    # Create shared translations for each group
    translation_groups.each do |source_idx, sharing_readings|
      source_reading = created_readings[source_idx]
      translation_text = source_reading[:data][:translation]

      # Create shared translation
      shared_translation = QiraatReadingTranslation.create!(source: 'Scholarly consensus', position: 1)
      LocalizedContent.create!(
        resource: shared_translation,
        language: @english,
        content_type: 'translation',
        text: translation_text
      )

      # Remove individual translation from source reading and link to shared
      LocalizedContent.where(
        resource: source_reading[:reading],
        content_type: 'translation'
      ).destroy_all

      QiraatReadingTranslationMembership.create!(
        qiraat_reading: source_reading[:reading],
        qiraat_reading_translation: shared_translation
      )

      # Link all readings that share this translation
      sharing_readings.each do |cr|
        QiraatReadingTranslationMembership.create!(
          qiraat_reading: cr[:reading],
          qiraat_reading_translation: shared_translation
        )
      end

      reading_nums = ([source_reading] + sharing_readings)
                       .map { |cr| cr[:reading].position }.sort.join(', ')
      puts "  ✓ Created shared translation for readings #{reading_nums}"
    end
  end

  def parse_header(header)
    parts = header.split(/\s+/, 2)
    surah_name = parts[0]
    verse_part = parts[1] || ''

    chapter_id = SURAH_MAP[surah_name]
    return nil unless chapter_id

    verses = if verse_part.include?('-')
               range = verse_part.split('-').map(&:to_i)
               (range[0]..range[1]).to_a
             else
               [verse_part.to_i]
             end

    { chapter_id: chapter_id, verses: verses, surah_name: surah_name }
  end

  # ---------------------------------------------------------------------------
  # DYNAMIC WORD POSITION LOOKUP
  # Search for the Arabic text in the verse's words to find positions
  # ---------------------------------------------------------------------------
  def find_word_positions(verses, base_text, readings_data)
    return nil if verses.empty?

    # Clean up the base text - remove diacritics for matching
    search_texts = []

    # Use base_text if available
    if base_text.present? && base_text.match?(/[\u0600-\u06FF]/)
      # Handle cross-segment text like "اتوني...اتوني" or "وإن ىكن…فإن ىكن"
      parts = base_text.split(/[\.…]+/).map(&:strip).reject(&:empty?)
      search_texts = parts
    end

    # If no base_text, try using the first reading's Arabic text
    if search_texts.empty? && readings_data.any?
      first_reading = readings_data.first[:arabic]
      if first_reading&.match?(/[\u0600-\u06FF]/)
        parts = first_reading.split(/[\.…]+/).map(&:strip).reject(&:empty?)
        search_texts = parts
      end
    end

    return nil if search_texts.empty?

    segments = []
    # Track used WORDS (not ranges) by verse:position
    used_word_positions = Set.new

    search_texts.each_with_index do |search_text, segment_idx|
      # Try to find this text in one of the verses
      found = false

      verses.each do |verse|
        # Find ALL matches in this verse, then pick one that doesn't overlap with used words
        all_matches = find_all_words_in_verse(verse, search_text)

        # Pick the first match that doesn't overlap with already-used words
        all_matches.each do |word_match|
          # Check if any word in this range is already used
          range = (word_match[:start]..word_match[:end])
          overlap = range.any? { |pos| used_word_positions.include?("#{verse.verse_number}:#{pos}") }

          unless overlap
            segments << {
              verse: verse.verse_number,
              start: word_match[:start],
              end: word_match[:end]
            }
            # Mark all words in this range as used
            range.each { |pos| used_word_positions.add("#{verse.verse_number}:#{pos}") }
            found = true
            break
          end
        end
        break if found
      end

      # If not found in verses, try to find partial match
      unless found
        verses.each do |verse|
          word_match = find_words_fuzzy(verse, search_text, used_word_positions)
          if word_match
            segments << {
              verse: verse.verse_number,
              start: word_match[:start],
              end: word_match[:end]
            }
            # Mark all words in this range as used
            (word_match[:start]..word_match[:end]).each { |pos| used_word_positions.add("#{verse.verse_number}:#{pos}") }
            break
          end
        end
      end
    end

    segments.empty? ? nil : segments
  end

  def find_all_words_in_verse(verse, search_text)
    # Get all words in the verse
    words = verse.words.order(:position).to_a
    clean_search = normalize_arabic(search_text)

    # Group matches by length (prefer shorter matches)
    matches_by_length = { 1 => [], 2 => [], 3 => [] }

    # Try to find consecutive words that match
    words.each_with_index do |start_word, start_idx|
      # Try matching 1, 2, or 3 consecutive words (in that order of preference)
      [1, 2, 3].each do |length|
        end_idx = start_idx + length - 1
        next if end_idx >= words.length

        # Combine words
        combined = words[start_idx..end_idx].map { |w| w.text_uthmani || w.text_imlaei }.join(' ')
        clean_combined = normalize_arabic(combined)

        # Check if it matches - prefer exact or near-exact matches
        if clean_combined == clean_search
          # Exact match - highest priority
          matches_by_length[length] << { start: start_word.position, end: words[end_idx].position, exact: true }
        elsif clean_combined.include?(clean_search)
          # Search text is contained in the word(s)
          matches_by_length[length] << { start: start_word.position, end: words[end_idx].position, exact: false }
        elsif clean_search.include?(clean_combined) && clean_combined.length >= clean_search.length * 0.7
          # Word(s) are contained in search text (partial match) - only if reasonably close
          matches_by_length[length] << { start: start_word.position, end: words[end_idx].position, exact: false }
        end
      end
    end

    # Return matches sorted by: 1) exact matches first, 2) shorter matches first, 3) earlier position first
    result = []

    # First add all exact matches, preferring shorter ones
    [1, 2, 3].each do |len|
      matches_by_length[len].select { |m| m[:exact] }.each do |m|
        result << { start: m[:start], end: m[:end] }
      end
    end

    # Then add non-exact matches, preferring shorter ones
    [1, 2, 3].each do |len|
      matches_by_length[len].reject { |m| m[:exact] }.each do |m|
        result << { start: m[:start], end: m[:end] }
      end
    end

    result
  end

  def find_words_in_verse(verse, search_text)
    # Get all words in the verse
    words = verse.words.order(:position).to_a

    # Clean the search text (remove some diacritics for fuzzy matching)
    clean_search = normalize_arabic(search_text)

    # Try to find consecutive words that match
    words.each_with_index do |start_word, start_idx|
      # Try matching 1, 2, or 3 consecutive words
      (1..3).each do |length|
        end_idx = start_idx + length - 1
        next if end_idx >= words.length

        # Combine words
        combined = words[start_idx..end_idx].map { |w| w.text_uthmani || w.text_imlaei }.join(' ')
        clean_combined = normalize_arabic(combined)

        # Check if it matches
        if clean_combined.include?(clean_search) || clean_search.include?(clean_combined)
          return { start: start_word.position, end: words[end_idx].position }
        end
      end
    end

    nil
  end

  def find_words_fuzzy(verse, search_text, used_positions = Set.new)
    words = verse.words.order(:position).to_a
    clean_search = normalize_arabic(search_text)

    # Find words with highest similarity
    best_match = nil
    best_score = 0

    words.each_with_index do |start_word, start_idx|
      (1..3).each do |length|
        end_idx = start_idx + length - 1
        next if end_idx >= words.length

        # Skip if any word in this range is already used
        range = (start_word.position..words[end_idx].position)
        overlap = range.any? { |pos| used_positions.include?("#{verse.verse_number}:#{pos}") }
        next if overlap

        combined = words[start_idx..end_idx].map { |w| normalize_arabic(w.text_uthmani || w.text_imlaei || '') }.join

        # Calculate character overlap
        score = (clean_search.chars & combined.chars).length.to_f / [clean_search.length, combined.length].max

        if score > best_score && score > 0.5
          best_score = score
          best_match = { start: start_word.position, end: words[end_idx].position }
        end
      end
    end

    best_match
  end

  def normalize_arabic(text)
    return '' if text.nil?
    # Remove common diacritics for fuzzy matching
    text.gsub(/[\u064B-\u065F\u0670]/, '')  # Remove harakat
        .gsub(/[\u0654-\u0655]/, '')         # Remove hamza markers
        .gsub(/[ٱ]/, 'ا')                    # Normalize alef wasla
        .gsub(/[إأآ]/, 'ا')                  # Normalize alef variants
        .gsub(/[ى]/, 'ي')                    # Normalize ya
        .gsub(/\s+/, '')                     # Remove spaces
  end

  # ---------------------------------------------------------------------------
  # PARSE READER ATTRIBUTION MATRIX
  # The CSV header rows contain reader/transmitter names that indicate splits
  # ---------------------------------------------------------------------------
  def parse_attribution_matrix(lines)
    matrix = { readers: [], transmitters: [], split_readers: [] }

    # Look at first few lines after juncture header for reader names
    lines[0..4].each do |line|
      row = CSV.parse_line(line) rescue []
      next if row.nil?

      row.each_with_index do |cell, idx|
        next if cell.nil?
        cell = cell.strip

        if READER_ABBREVIATIONS.include?(cell)
          matrix[:readers] << { name: cell, column: idx }
        elsif TRANSMITTER_ABBREVIATIONS.include?(cell)
          matrix[:transmitters] << { name: cell, column: idx }
          # If transmitter is shown, the reader above is split
          # Find which reader this transmitter belongs to
          parent_col = matrix[:readers].select { |r| r[:column] <= idx }.max_by { |r| r[:column] }
          if parent_col
            matrix[:split_readers] << parent_col[:name] unless matrix[:split_readers].include?(parent_col[:name])
          end
        end
      end
    end

    matrix
  end

  # ---------------------------------------------------------------------------
  # PARSE READINGS
  # ---------------------------------------------------------------------------
  def parse_readings(lines)
    readings = []

    lines.each do |line|
      row = CSV.parse_line(line) rescue []
      next if row.nil?

      first_cell = row[0]&.strip || ''
      second_cell = row[1]&.strip || ''
      fourth_cell = row[3]&.strip || ''

      # A reading row has: empty first cell, Arabic in second, transliteration in fourth
      next unless first_cell.empty?
      next unless second_cell.match?(/[\u0600-\u06FF]/)
      next unless fourth_cell.present? && fourth_cell.match?(/[a-zA-Z]/)

      translation = row[7]&.strip || ''
      translation = translation.gsub(/^"|"$/, '').gsub('""', '"').gsub(/^""|""$/, '"')

      readings << {
        arabic: second_cell,
        transliteration: fourth_cell,
        translation: translation.presence
      }
    end

    attach_explanations(readings, lines)
    readings
  end

  def attach_explanations(readings, lines)
    reading_idx = 0
    lines.each do |line|
      row = CSV.parse_line(line) rescue []
      next if row.nil?

      first_cell = row[0]&.strip || ''
      second_cell = row[1]&.strip || ''
      fourth_cell = row[3]&.strip || ''

      # Reading row - move to next reading
      if first_cell.empty? && second_cell.match?(/[\u0600-\u06FF]/) && fourth_cell.present? && fourth_cell.match?(/[a-zA-Z]/)
        reading_idx = readings.index { |r| r[:arabic] == second_cell }
        reading_idx = (reading_idx || -1) + 1
        next
      end

      # Explanation row
      if first_cell.empty? && second_cell.present? &&
         !second_cell.match?(/[\u0600-\u06FF]/) &&
         (fourth_cell.nil? || fourth_cell.empty?) &&
         !combined_explanation?(second_cell) &&
         reading_idx > 0 && reading_idx <= readings.length

        reading = readings[reading_idx - 1]
        reading[:explanation] ||= ''
        reading[:explanation] += ' ' unless reading[:explanation].empty?
        reading[:explanation] += second_cell
      end
    end
  end

  def combined_explanation?(text)
    text.match?(/These readings|Combined translation|complementary meanings|identical in meaning|linguistic options|amount to the same|provide complementary/i)
  end

  def parse_combined_explanation(lines)
    lines.each do |line|
      row = CSV.parse_line(line) rescue []
      next if row.nil?

      second_cell = row[1]&.strip || ''
      return second_cell if combined_explanation?(second_cell)
    end
    nil
  end

  # ---------------------------------------------------------------------------
  # CREATE READING
  # ---------------------------------------------------------------------------
  def create_reading(juncture, reading_data, position, juncture_info, attribution_matrix, verses)
    reading = QiraatReading.create!(
      qiraat_juncture: juncture,
      text_uthmani: reading_data[:arabic],
      position: position,
      color: SEED_COLORS[position] || SEED_COLORS[1]
    )

    # DYNAMIC: Infer attributions from the matrix and reading position
    # For now, we'll distribute readers evenly across readings if we can't determine from CSV
    # This is a limitation of the format - colors aren't preserved in CSV
    add_inferred_attributions(reading, position, juncture.qiraat_readings.count, attribution_matrix)

    # Add transliteration
    if reading_data[:transliteration].present?
      LocalizedContent.create!(
        resource: reading,
        language: @english,
        content_type: 'transliteration',
        text: reading_data[:transliteration]
      )
    end

    # Add translation
    if reading_data[:translation].present?
      LocalizedContent.create!(
        resource: reading,
        language: @english,
        content_type: 'translation',
        text: reading_data[:translation]
      )
    end

    # Add explanation
    if reading_data[:explanation].present?
      exp = QiraatReadingExplanation.create!(source: 'Scholarly consensus', position: 1)
      LocalizedContent.create!(
        resource: exp,
        language: @english,
        content_type: 'explanation',
        text: reading_data[:explanation].strip
      )
      QiraatReadingExplanationMembership.create!(
        qiraat_reading: reading,
        qiraat_reading_explanation: exp
      )
    end

    puts "  ✓ Reading #{position}: #{reading_data[:arabic]}"
    reading
  end

  def add_inferred_attributions(reading, position, total_readings, attribution_matrix)
    # Get all readers
    all_readers = @readers.values

    # If there's only 1 reading, all readers use it
    if total_readings == 1
      all_readers.each do |reader|
        QiraatReadingAttribution.create!(qiraat_reading: reading, qiraat_reader: reader)
      end
      return
    end

    # For multiple readings, we can't determine attribution from CSV format alone
    # The original Excel had colored cells to show this
    # For now, just add a note that attributions need manual review
    puts "    ⚠️  Attributions could not be inferred from CSV (color data lost)"

    # As a fallback, we won't add any attributions - they'll need to be added manually
    # This is more honest than guessing wrong
  end
end
