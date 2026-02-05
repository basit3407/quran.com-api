# frozen_string_literal: true

namespace :hadith_references do
  desc 'Seed hadith references from public/openquran_refs_with_collection.json'
  task seed: :environment do
    file_path = Rails.root.join('public', 'openquran_refs_with_collection.json')

    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end

    batch_size = ENV.fetch('BATCH_SIZE', 1000).to_i
    batch_size = 1000 if batch_size <= 0

    puts "Seeding hadith references from #{file_path}..."
    HadithReference.delete_all

    now = Time.current
    batch = []
    total = 0

    Oj.load_file(file_path.to_s).each do |row|
      start_key = "#{row['surahNumber']}:#{row['ayahStartNumber']}"
      end_key = "#{row['surahNumber']}:#{row['ayahEndNumber']}"
      start_index = QuranUtils::Quran.get_ayah_id_from_key(start_key)
      end_index = QuranUtils::Quran.get_ayah_id_from_key(end_key)

      if start_index.nil? || end_index.nil?
        raise "Invalid ayah key(s): #{start_key} -> #{end_key}"
      end

      batch << {
        collection: row['collection'],
        hadith_number: row['hadithNumber'].to_s,
        our_hadith_number: row['ourHadithNumber'],
        arabic_urn: row['arabicURN'],
        english_urn: row['englishURN'],
        ayah_start_index: start_index,
        ayah_end_index: end_index,
        created_at: now,
        updated_at: now
      }

      next unless batch.size >= batch_size

      HadithReference.insert_all!(batch)
      total += batch.size
      batch.clear
    end

    if batch.any?
      HadithReference.insert_all!(batch)
      total += batch.size
    end

    puts "Done. Seeded #{total} hadith references."
  end

  desc 'Clear all hadith references'
  task clear: :environment do
    count = HadithReference.delete_all
    puts "Done. Deleted #{count} hadith references."
  end
end
