class AddSongMasterToSongs < ActiveRecord::Migration[6.1]
  def change
    # nullable: 既存Songは未設定のまま(rake song_performances:backfillで一括解決)。
    # 新規Songは保存時にSongモデルのコールバックが自動的に解決・設定する。
    add_reference :songs, :song_master, null: true, foreign_key: true, index: true
  end
end
