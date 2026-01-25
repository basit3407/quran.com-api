# frozen_string_literal: true

FactoryBot.define do
  factory :relation_type do
    sequence(:name) { |n| "relation_type_#{n}" }

    trait :with_translations do
      after(:create) do |relation_type|
        create(:localized_content, resource: relation_type, language: Language.default, content_type: 'translation', text: 'Sample Translation')
      end
    end
  end
end