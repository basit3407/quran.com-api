FactoryBot.define do
  factory :mushaf do
    name { 'Indopak' }
    is_default { false }
    enabled { true }
    pages_count { 604 }
    lines_per_page { 15 }

    trait :default do
      is_default { true }
    end

    trait :indopak do
      name { 'Indopak' }
      lines_per_page { 16 }
      # IDs from Mushaf::INDOPAK_MUSHAFS
      id { 6 } 
    end

    trait :uthmani do
      name { 'Uthmani' }
      lines_per_page { 15 }
    end
  end
end