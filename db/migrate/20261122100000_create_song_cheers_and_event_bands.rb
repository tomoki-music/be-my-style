require_relative "../../lib/migration_lock_wait_timeout"

class CreateSongCheersAndEventBands < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # 楽曲の「応援する📣」と、イベントのバンド出演枠。
  #
  # song_cheers は演奏エントリー(join_part_customers)とは別テーブルにする。成立判定・募集パート・演奏実績・
  # エントリー依頼候補・参加人数/料金の集計はすべて join_part_customers を見ているため、別テーブルなら
  # どれにも混ざらない。同じ人の応援は同じ曲に1件までなので (song_id, customer_id) を一意にする。
  #
  # event_bands / event_band_members はバンド名とパートごとの固定担当者。担当者は会員(customer_id)か
  # 未登録の出演者の表示名(display_name)のどちらか。songs.event_band_id があればバンド出演曲として扱い、
  # 一般の演奏エントリーとエントリー依頼の対象から外す。
  #
  # 途中で失敗しても再実行できるよう、テーブル・列・索引・外部キーの有無を確認してから作る(MySQL の DDL は巻き戻らない)。
  def up
    unless table_exists?(:song_cheers)
      create_table :song_cheers do |t|
        t.bigint :song_id, null: false
        t.bigint :customer_id, null: false
        t.timestamps
      end
    end
    add_index :song_cheers, [:song_id, :customer_id], unique: true unless index_exists?(:song_cheers, [:song_id, :customer_id])
    add_index :song_cheers, :customer_id unless index_exists?(:song_cheers, :customer_id)
    add_foreign_key :song_cheers, :songs, on_delete: :cascade unless foreign_key_exists?(:song_cheers, :songs)
    add_foreign_key :song_cheers, :customers unless foreign_key_exists?(:song_cheers, :customers)

    unless table_exists?(:event_bands)
      create_table :event_bands do |t|
        t.bigint :event_id, null: false
        t.string :name, null: false, limit: 100
        t.timestamps
      end
    end
    add_index :event_bands, :event_id unless index_exists?(:event_bands, :event_id)
    add_foreign_key :event_bands, :events, on_delete: :cascade unless foreign_key_exists?(:event_bands, :events)

    unless table_exists?(:event_band_members)
      create_table :event_band_members do |t|
        t.bigint :event_band_id, null: false
        t.string :part_name, null: false, limit: 20
        t.bigint :customer_id
        t.string :display_name, limit: 50
        t.timestamps
      end
    end
    unless index_exists?(:event_band_members, [:event_band_id, :part_name])
      add_index :event_band_members, [:event_band_id, :part_name], unique: true
    end
    add_index :event_band_members, :customer_id unless index_exists?(:event_band_members, :customer_id)
    unless foreign_key_exists?(:event_band_members, :event_bands)
      add_foreign_key :event_band_members, :event_bands, on_delete: :cascade
    end
    unless foreign_key_exists?(:event_band_members, :customers)
      add_foreign_key :event_band_members, :customers, on_delete: :nullify
    end

    add_column :songs, :event_band_id, :bigint unless column_exists?(:songs, :event_band_id)
    add_index :songs, :event_band_id unless index_exists?(:songs, :event_band_id)
    add_foreign_key :songs, :event_bands, on_delete: :nullify unless foreign_key_exists?(:songs, :event_bands)
  end

  def down
    remove_foreign_key :songs, :event_bands if foreign_key_exists?(:songs, :event_bands)
    remove_column :songs, :event_band_id if column_exists?(:songs, :event_band_id)
    drop_table :event_band_members if table_exists?(:event_band_members)
    drop_table :event_bands if table_exists?(:event_bands)
    drop_table :song_cheers if table_exists?(:song_cheers)
  end
end
