# frozen_string_literal: true

FactoryBot.define do
  factory :reciter do
    sequence(:name) { |n| "Reciter #{n}" }
    bio { 'Default biography' }
    profile_picture { nil }
    cover_image { nil }
    recitations_count { 0 }

    trait :with_bio do
      bio { 'Famous reciter with beautiful voice' }
    end

    trait :with_localized_bio do
      transient do
        language { nil }
        bio_text { 'Localized biography text' }
      end

      after(:create) do |reciter, evaluator|
        if evaluator.language
          create(:localized_content, :bio,
                 resource: reciter,
                 language: evaluator.language,
                 text: evaluator.bio_text)
        end
      end
    end
  end
end
