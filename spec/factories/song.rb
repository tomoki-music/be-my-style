FactoryBot.define do
  factory :song do
    sequence(:song_name) { |n| "song#{n}" }
    sequence(:youtube_url) { |n| "youtube_url#{n}" }
    sequence(:introduction) { |n| "introduction#{n}" }
    event
    trait :song_with_parts do
      after(:build) do |song|
        song.join_parts << build(:join_part)
      end
    end
    trait :with_chord_sheet do
      chord_sheet_url { "https://example.com/chord-sheet" }
      musical_key { "G" }
      capo { 2 }
      chord_sheet_note { "初心者向けの簡単コード版です" }
    end
    trait :with_tab_sheet do
      tab_sheet_url { "https://example.com/tab-sheet" }
    end
    trait :with_requester do
      association :requested_by_customer, factory: :customer
    end
  end
end