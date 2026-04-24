FactoryBot.define do
  factory :singing_diagnosis do
    association :customer, domain_name: "singing"
    song_title { "Sample Song" }
    memo { "歌唱・演奏診断のメモ" }
    status { :queued }
    performance_type { :vocal }

    after(:build) do |diagnosis|
      diagnosis.audio_file.attach(
        io: StringIO.new("audio"),
        filename: "sample.mp3",
        content_type: "audio/mpeg"
      )
    end
  end
end
