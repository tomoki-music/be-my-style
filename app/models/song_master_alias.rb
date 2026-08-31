# 旧表記の正規化キー -> 正SongMaster の解決エイリアス。
#
# SongMasters::Merge が分裂SongMasterを統合するときに、統合元の正規化キーを1件記録する。
# SongMasters::Resolver は通常のSongMaster完全一致で解決できなかったときだけ、この表を引く
# (二次解決)。詳細は db/migrate/20260831000000_create_song_master_aliases.rb を参照。
class SongMasterAlias < ApplicationRecord
  belongs_to :song_master

  validates :normalized_song_name, presence: true
  # DBの複合UNIQUE制約(index_song_master_aliases_on_normalized_name_and_artist)と揃える。
  validates :normalized_song_name, uniqueness: { scope: :normalized_artist_name }
  # normalized_artist_name は song_masters と同じく「未設定 = 空文字」で扱う(NULL不可)。
  validates :normalized_artist_name, exclusion: { in: [nil] }
end
