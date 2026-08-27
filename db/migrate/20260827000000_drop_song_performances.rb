class DropSongPerformances < ActiveRecord::Migration[6.1]
  # song_performancesは、20260826010200_create_song_performances.rbで新設したテーブル。
  # 演奏実績の正データを「終了済みイベントに現存するJoinPartCustomer」を動的に読む方式へ
  # 変更したため、専用の同期先テーブルとしての役割が不要になった。
  #
  # このPR(#156)は未マージ・本番未適用のため、20260826010200のファイル自体は書き換えず、
  # 適用済みmigration履歴を安易に書き換えない方針を優先し、新しいmigrationでdrop_tableする。
  # downでは20260826010200と同じ定義でテーブルを復元できるようにしておく。
  def up
    drop_table :song_performances
  end

  def down
    create_table :song_performances do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :song_master, null: false, foreign_key: true
      t.references :song, null: true, foreign_key: true
      t.references :event, null: true, foreign_key: true
      t.references :join_part, null: true, foreign_key: true
      t.string :part_name, null: false
      t.date :performed_on

      t.timestamps
    end

    add_index :song_performances, [:customer_id, :song_master_id, :part_name, :event_id],
      unique: true, name: "index_song_performances_on_customer_song_part_event"
    add_index :song_performances, [:song_master_id, :part_name],
      name: "index_song_performances_on_song_master_and_part"
  end
end
