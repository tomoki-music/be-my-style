FactoryBot.define do
  factory :song_master_alias do
    song_master

    # デフォルトでは「旧曲名（旧アーティスト）」のような、正規化キーが song_master 本体と
    # 別物になる旧表記を模した値を入れる。個別テストで上書きする。
    sequence(:normalized_song_name) { |n| SongMasters::Resolver.normalize("legacy song #{n}") }
    normalized_artist_name { "" }
  end
end
