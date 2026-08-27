class CreateSongPerformances < ActiveRecord::Migration[6.1]
  def change
    # イベントでの演奏実績(customer x song_master x part x event)。
    # 自己申告の演奏可能曲は別テーブル(customer_song_parts)で管理し、テーブル自体で
    # 「実績」と「自己申告」を明確に区別する(record_type等のnullableカラムに頼らない)。
    create_table :song_performances do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :song_master, null: false, foreign_key: true
      # 実際に演奏したSong行への参照。Song/Event削除後も実績履歴を残すため、
      # song_templates.source_song_id等と同様にモデル側でdependent: :nullifyする
      # (そのためDB上はnullableにしておく。新規作成時はアプリ側で必須にする)。
      t.references :song, null: true, foreign_key: true
      t.references :event, null: true, foreign_key: true
      t.references :join_part, null: true, foreign_key: true
      t.string :part_name, null: false
      t.date :performed_on

      t.timestamps
    end

    # customer x song_master x part x event の重複登録を防ぐ。4カラムとも
    # アプリ側では常にNOT NULLとして運用するため、MySQLのNULL特性の影響を受けない。
    add_index :song_performances, [:customer_id, :song_master_id, :part_name, :event_id],
      unique: true, name: "index_song_performances_on_customer_song_part_event"
    add_index :song_performances, [:song_master_id, :part_name],
      name: "index_song_performances_on_song_master_and_part"
  end
end
