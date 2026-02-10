# frozen_string_literal: true

FactoryBot.define do
  factory :hadith_reference do
    collection { 'bukhari' }
    sequence(:hadith_number) { |n| n.to_s }
    sequence(:our_hadith_number) { |n| n }
    sequence(:arabic_urn) { |n| 100_000 + n }
    sequence(:english_urn) { |n| 200_000 + n }
    ayah_start_index { 1 }
    ayah_end_index { ayah_start_index }

    transient do
      ayah_start_key { nil }
      ayah_end_key { nil }
    end

    before(:validation) do |reference, evaluator|
      if evaluator.ayah_start_key
        reference.ayah_start_index = QuranUtils::Quran.get_ayah_id_from_key(evaluator.ayah_start_key)
      end
      if evaluator.ayah_end_key
        reference.ayah_end_index = QuranUtils::Quran.get_ayah_id_from_key(evaluator.ayah_end_key)
      end
    end
  end
end
