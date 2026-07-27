FactoryBot.define do
  factory :song_template do
    association :community
    association :customer
    sequence(:song_name) { |n| "song_template#{n}" }

    trait :with_chord_sheet do
      chord_sheet_url { "https://example.com/chord-sheet" }
      musical_key { "G" }
      capo { 2 }
      chord_sheet_note { "初心者向けの簡単コード版です" }
    end

    trait :with_tab_sheet do
      tab_sheet_url { "https://example.com/tab-sheet" }
    end
  end
end
