require_relative "../../lib/migration_lock_wait_timeout"

class CreateEventBandCheers < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # バンド出演枠への「このバンドを応援する📣」。曲への応援(song_cheers)とは独立したテーブルで、
  # 参加人数・料金・成立判定などの集計(join_part_customers を見る)には混ざらない。
  # 同じ会員はイベント内の同じバンドにつき1件まで((event_band_id, customer_id) を一意にする)。
  #
  # 途中で失敗しても再実行できるよう、テーブル・索引・外部キーの有無を確認してから作る(MySQL の DDL は巻き戻らない)。
  def up
    unless table_exists?(:event_band_cheers)
      create_table :event_band_cheers do |t|
        t.bigint :event_band_id, null: false
        t.bigint :customer_id, null: false
        t.timestamps
      end
    end
    unless index_exists?(:event_band_cheers, [:event_band_id, :customer_id])
      add_index :event_band_cheers, [:event_band_id, :customer_id], unique: true
    end
    add_index :event_band_cheers, :customer_id unless index_exists?(:event_band_cheers, :customer_id)
    unless foreign_key_exists?(:event_band_cheers, :event_bands)
      add_foreign_key :event_band_cheers, :event_bands, on_delete: :cascade
    end
    add_foreign_key :event_band_cheers, :customers unless foreign_key_exists?(:event_band_cheers, :customers)
  end

  def down
    drop_table :event_band_cheers if table_exists?(:event_band_cheers)
  end
end
