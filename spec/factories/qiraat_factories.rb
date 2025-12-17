# frozen_string_literal: true

# FactoryBot factories for Qiraat models

FactoryBot.define do
  factory :language do
    sequence(:name) { |n| "Language #{n}" }
    sequence(:iso_code) { |n| "lg#{n}" }
    native_name { name }
    direction { 'ltr' }

    trait :english do
      name { 'English' }
      iso_code { 'en' }
      native_name { 'English' }
    end

    trait :arabic do
      name { 'Arabic' }
      iso_code { 'ar' }
      native_name { 'العربية' }
      direction { 'rtl' }
    end
  end

  factory :chapter do
    sequence(:chapter_number) { |n| 100 + n }  # Start at 100 to avoid conflicts
    name_simple { "Chapter #{chapter_number}" }
    name_arabic { "سورة #{chapter_number}" }
    verses_count { 10 }
    bismillah_pre { chapter_number != 9 }
    revelation_place { 'makkah' }
    revelation_order { chapter_number }
  end

  factory :verse do
    transient do
      use_chapter { nil }
    end

    chapter_id { use_chapter&.id || (chapter&.id rescue Chapter.first&.id) || create(:chapter).id }
    sequence(:verse_number) { |n| n }
    verse_key { "#{chapter_id}:#{verse_number}" }
    text_uthmani { 'أَرْسِلْهُ مَعَنَا غَدًا يَرْتَعْ وَيَلْعَبْ' }
    text_imlaei { 'ارسله معنا غدا يرتع ويلعب' }

    after(:build) do |verse|
      verse.chapter_id ||= create(:chapter).id
    end
  end

  factory :qiraat_reader do
    sequence(:name) { |n| "Reader #{n}" }
    sequence(:abbreviation) { |n| "R#{n}" }
    sequence(:position)
    death_year_hijri { rand(100..250) }
    death_year_gregorian { rand(700..900) }
    name_translations { { 'en' => name, 'ar' => name } }
  end

  factory :qiraat_transmitter do
    association :qiraat_reader
    sequence(:name) { |n| "Transmitter #{n}" }
    sequence(:abbreviation) { |n| "T#{n}" }
    is_primary { false }
    sequence(:position)
    death_year_hijri { rand(150..300) }
    death_year_gregorian { rand(750..950) }
    name_translations { { 'en' => name, 'ar' => name } }

    trait :primary do
      is_primary { true }
    end
  end

  factory :qiraat_juncture do
    sequence(:position)
    flags { ['grammatical'] }
    juz_number { 1 }
    hizb_number { 1 }
  end

  factory :qiraat_juncture_segment do
    association :qiraat_juncture
    association :verse
    association :start_word, factory: :word
    association :end_word, factory: :word
    sequence(:position)

    before(:create) do |segment|
      # Ensure words belong to the same verse
      if segment.start_word && segment.start_word.verse_id != segment.verse_id
        segment.start_word.update!(verse_id: segment.verse_id)
      end
      if segment.end_word && segment.end_word.verse_id != segment.verse_id
        segment.end_word.update!(verse_id: segment.verse_id)
      end
    end
  end

  factory :word do
    association :verse
    sequence(:position)
    text_uthmani { 'أَخَاكَ' }
    text_imlaei { 'أخاك' }
    text_qpc_hafs { 'أَخَاكَ' }
    char_type_name { 'word' }
  end

  factory :qiraat_reading do
    association :qiraat_juncture
    text_uthmani { 'أَخَاكَ' }
    text_imlaei { 'أخاك' }
    grammatical_form { 'accusative' }
    root_letters { 'أ خ و' }
    sequence(:position)
  end

  factory :qiraat_reading_attribution do
    association :qiraat_reading
    association :qiraat_reader
    qiraat_transmitter { nil }

    trait :with_transmitter do
      association :qiraat_transmitter
    end
  end

  factory :localized_content do
    association :resource, factory: :qiraat_reader
    association :language
    content_type { 'translation' }
    text { 'Sample text' }
    source { 'Test source' }
    metadata { {} }

    trait :bio do
      content_type { 'bio' }
      text { 'Biography text' }
    end

    trait :translation do
      content_type { 'translation' }
    end

    trait :transliteration do
      content_type { 'transliteration' }
    end

    trait :explanation do
      content_type { 'explanation' }
    end
  end

  factory :qiraat_reading_explanation do
    source { 'al-Alusi' }
    sequence(:position)

    trait :with_localized_content do
      transient do
        language { nil }
        explanation_text { 'Explanation text for the reading' }
      end

      after(:create) do |explanation, evaluator|
        if evaluator.language
          create(:localized_content,
                 resource: explanation,
                 language: evaluator.language,
                 content_type: 'explanation',
                 text: evaluator.explanation_text)
        end
      end
    end

    trait :shared do
      transient do
        readings_count { 2 }
      end

      after(:create) do |explanation, evaluator|
        create_list(:qiraat_reading_explanation_membership, evaluator.readings_count,
                    qiraat_reading_explanation: explanation)
      end
    end
  end

  factory :qiraat_reading_explanation_membership do
    association :qiraat_reading
    association :qiraat_reading_explanation
  end

  factory :qiraat_reading_translation do
    source { 'Bridges Translation' }
    sequence(:position)

    trait :with_localized_content do
      transient do
        language { nil }
        translation_text { 'Translation text for the reading' }
      end

      after(:create) do |translation, evaluator|
        if evaluator.language
          create(:localized_content,
                 resource: translation,
                 language: evaluator.language,
                 content_type: 'translation',
                 text: evaluator.translation_text)
        end
      end
    end

    trait :shared do
      transient do
        readings_count { 2 }
      end

      after(:create) do |translation, evaluator|
        create_list(:qiraat_reading_translation_membership, evaluator.readings_count,
                    qiraat_reading_translation: translation)
      end
    end
  end

  factory :qiraat_reading_translation_membership do
    association :qiraat_reading
    association :qiraat_reading_translation
  end
end
