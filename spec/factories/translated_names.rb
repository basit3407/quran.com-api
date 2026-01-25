# frozen_string_literal: true

FactoryBot.define do
  factory :translated_name do
    sequence(:name) { |n| "Translated Name #{n}" }
    language_priority { 1 }
    association :resource, factory: :chapter
    association :language
  end
end