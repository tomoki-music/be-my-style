module SongMasters
  # 「曲名（アーティスト名）」「アーティスト - 曲名」等の分解可否を判定するための"裏付け"集合を組み立てる。
  #
  # 裏付けとして採用するのは、向きが曖昧でない次の2つだけ:
  #   - 「曲名」と「アーティスト名」が別カラムで入力されたSong
  #   - 既存SongMaster(normalized_artist_name が非空のもの)
  #
  # 末尾括弧「曲名（アーティスト名）」そのものや区切り「A - B」は、向きが一意に定まらない/
  # 「Q（キュー）」のような読み仮名括弧を自己参照で分解してしまうため、裏付けの供給源にはしない
  # (それらは「照合される側」であって「裏付ける側」ではない)。
  #
  # 戻り値は Resolver の artist_corroboration: に渡せる lambda。
  # Songの走査を一度だけ行うことで、backfill時のSong処理順に依存しない判定になる。
  module ArtistCorroboration
    # songs: [song_name, artist_name] の配列、または nil(その場合 Song 全件を読む)。
    def self.build(songs: nil)
      pairs = songs || Song.pluck(:song_name, :artist_name)

      keys = SongMaster.where.not(normalized_artist_name: "")
        .pluck(:normalized_song_name, :normalized_artist_name)
        .to_set

      pairs.each do |song_name, artist_name|
        next if artist_name.blank?

        nsn = SongMasters::Resolver.normalize(song_name)
        nan = SongMasters::Resolver.normalize(artist_name)
        keys << [nsn, nan] if nsn.present? && nan.present?
      end

      lambda do |normalized_song_name:, normalized_artist_name:|
        normalized_artist_name.present? && keys.include?([normalized_song_name, normalized_artist_name])
      end
    end
  end
end
