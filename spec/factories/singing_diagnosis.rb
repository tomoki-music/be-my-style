FactoryBot.define do
  factory :singing_diagnosis do
    association :customer, domain_name: "singing"
    song_title { "Sample Song" }
    memo { "歌唱・演奏診断のメモ" }
    status { :queued }
    performance_type { :vocal }
    ranking_opt_in { false }

    after(:build) do |diagnosis|
      diagnosis.audio_file.attach(
        io: StringIO.new("audio"),
        filename: "sample.mp3",
        content_type: "audio/mpeg"
      )
    end

    trait :completed do
      status { :completed }
      overall_score { 75 }
      pitch_score { 72 }
      rhythm_score { 76 }
      expression_score { 73 }
      diagnosed_at { Time.current }
    end

    trait :ranking_participant do
      ranking_opt_in { true }
    end
  end
end
