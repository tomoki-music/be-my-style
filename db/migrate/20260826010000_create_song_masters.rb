class CreateSongMasters < ActiveRecord::Migration[6.1]
  def change
    create_table :song_masters do |t|
      # 曲名・アーティスト名をNFKC正規化(全角/半角・大文字小文字ゆれ吸収)したキー。
      # イベントごとに別レコードとなるSongを「同じ曲」として名寄せするための識別子。
      t.string :normalized_song_name, null: false
      # アーティスト名未設定のSongも正規化キーの一部として扱うため、NULLではなく
      # 空文字を既定値にする(MySQLはUNIQUE indexでNULL同士を別値として扱い重複を防げないため)。
      t.string :normalized_artist_name, null: false, default: ""
      # 表示用の代表値(最初に見つかったSongの表記をそのまま保持)。
      t.string :song_name, null: false
      t.string :artist_name

      t.timestamps
    end

    add_index :song_masters, [:normalized_song_name, :normalized_artist_name],
      unique: true, name: "index_song_masters_on_normalized_name_and_artist"
  end
end
