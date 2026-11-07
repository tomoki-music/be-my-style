require_relative "../../lib/migration_lock_wait_timeout"

class CreateEventCommunities < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # イベントの開催コミュニティ(複数)。events.community_id は「主催コミュニティ」として残す:
  # 編集権限・リマインド送信先などの基準はこの列のままなので、列の削除や NULL 許容への変更はしない。
  # 既存イベントは主催コミュニティを開催コミュニティの1件目として引き継ぐ。
  #
  # MySQL の DDL はトランザクションで巻き戻らないため、途中で失敗しても再実行できるよう各手順を冪等にしている。
  # 外部キーの ON DELETE CASCADE は、モデルを経由しない削除でこの表が親の削除を妨げないようにするため。
  def up
    unless table_exists?(:event_communities)
      create_table :event_communities do |t|
        t.bigint :event_id, null: false
        t.bigint :community_id, null: false
        t.timestamps
      end
    end

    add_index :event_communities, [:event_id, :community_id], unique: true unless index_exists?(:event_communities, [:event_id, :community_id])
    add_index :event_communities, :community_id unless index_exists?(:event_communities, :community_id)
    add_foreign_key :event_communities, :events, on_delete: :cascade unless foreign_key_exists?(:event_communities, :events)
    add_foreign_key :event_communities, :communities, on_delete: :cascade unless foreign_key_exists?(:event_communities, :communities)

    execute <<~SQL.squish
      INSERT INTO event_communities (event_id, community_id, created_at, updated_at)
      SELECT events.id, events.community_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM events
      WHERE NOT EXISTS (
        SELECT 1 FROM event_communities existing
        WHERE existing.event_id = events.id AND existing.community_id = events.community_id
      )
    SQL
  end

  # events.community_id は変更していないため、戻しても主催コミュニティは失われない
  # (追加した開催コミュニティの設定だけが消える)。
  def down
    drop_table :event_communities if table_exists?(:event_communities)
  end
end
