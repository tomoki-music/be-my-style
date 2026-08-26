FactoryBot.define do
  factory :song_master do
    # normalized_song_name/normalized_artist_nameを手動で指定するテスト(UNIQUE制約の
    # 検証等)のために、normalize: falseで自動計算をスキップできるようにしている。
    transient do
      normalize { true }
    end

    sequence(:song_name) { |n| "song_master#{n}" }
    sequence(:artist_name) { |n| "artist#{n}" }

    after(:build) do |song_master, evaluator|
      if evaluator.normalize
        song_master.normalized_song_name = SongMasters::Resolver.normalize(song_master.song_name)
        song_master.normalized_artist_name = SongMasters::Resolver.normalize(song_master.artist_name)
      end
    end
  end
end
