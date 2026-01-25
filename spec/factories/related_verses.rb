# frozen_string_literal: true

FactoryBot.define do
  factory :related_verse do
    verse
    related_verse { association :verse }
    relation_type
    approved { false }

    trait :approved do
      approved { true }
    end
  end
end