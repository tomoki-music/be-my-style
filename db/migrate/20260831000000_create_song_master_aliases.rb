class CreateSongMasterAliases < ActiveRecord::Migration[6.1]
  def change
    # 旧表記(引用符・括弧・区切り文字・アーティスト併記等のゆれ)の正規化キーを、
    # 「正」とするSongMasterへ恒久的に解決するためのエイリアス表。
    #
    # SongMasters::Resolver.normalize は意味的な表記ゆれ(丸の内/丸ノ内、略称、feat.表記、
    # 「曲名／アーティスト」併記など)を誤統合防止のためあえて吸収しない。そのため本来同一の
    # 楽曲でも別SongMasterへ分裂することがある。分裂SongMasterを統合(SongMasters::Merge)する際、
    # 統合元の正規化キーをここへ退避し、Resolverの二次解決に使うことで、同じ旧表記のSongが
    # 再保存されても分裂SongMasterが再作成されないようにする。
    create_table :song_master_aliases do |t|
      # このエイリアスが解決先とする「正」のSongMaster。
      t.references :song_master, null: false, foreign_key: true
      # 統合元SongMasterが持っていた正規化キー。song_masters と同じ正規化規則
      # (SongMasters::Resolver.normalize)で作る。normalized_artist_name は
      # song_masters と揃えて NULL ではなく空文字を既定値にする。
      t.string :normalized_song_name, null: false
      t.string :normalized_artist_name, null: false, default: ""

      t.timestamps
    end

    # 1つの旧正規化キーは高々1つの正SongMasterにしか解決しない。
    add_index :song_master_aliases, [:normalized_song_name, :normalized_artist_name],
      unique: true, name: "index_song_master_aliases_on_normalized_name_and_artist"
  end
end
