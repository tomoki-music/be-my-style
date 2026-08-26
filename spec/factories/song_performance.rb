FactoryBot.define do
  factory :song_performance do
    customer
    song
    event
    join_part
    part_name { "Vocal" }
    performed_on { Time.current.to_date }

    after(:build) do |song_performance|
      song_performance.song_master ||= song_performance.song&.song_master || FactoryBot.create(:song_master)
    end
  end
end
