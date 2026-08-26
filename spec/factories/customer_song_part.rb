FactoryBot.define do
  factory :customer_song_part do
    customer
    song
    part_name { "Vocal" }

    after(:build) do |customer_song_part|
      customer_song_part.song_master ||= customer_song_part.song&.song_master || FactoryBot.create(:song_master)
    end
  end
end
