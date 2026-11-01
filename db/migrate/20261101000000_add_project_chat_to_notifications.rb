require_relative "../../lib/migration_lock_wait_timeout"

class AddProjectChatToNotifications < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  INDEX_NAME = "index_notifications_on_project_chat_id_and_visited_id".freeze

  # スレッド投稿の通知を投稿ごとに持ち、同じ投稿・同じ宛先の通知を重複させない(再実行・同時実行でも1件)。
  # 既存の通知は NULL のまま(一意制約は NULL 同士では重複にならない)。
  #
  # notifications は全ドメイン共通の大きな表なので、MySQL では方式を明示し、使えない場合は表をコピーせずに失敗させる。
  #   列追加   ALGORITHM=INSTANT          : 表を書き換えない(データ辞書の変更だけ)
  #   一意索引 ALGORITHM=INPLACE, LOCK=NONE : 作成中も読み書きできる
  # どちらも開始時と終了時に短時間の排他メタデータロックを取る。notifications を使う長いトランザクションが残っていると
  # その終了を待ち、待っている間は後続の notifications への問い合わせも待たされる。待ちは MigrationLockWaitTimeout で
  # 5秒に制限し、超えたらこのマイグレーションは失敗する(schema_migrations に記録されない)ので、原因の解消後に再実行する。
  # 外部キーは付けない(MySQL は外部キー追加で表をコピーする)。投稿の削除時は ProjectChat 側で通知を消す。
  # 途中で失敗しても再実行できるよう、列・索引の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_project_chat_column unless column_exists?(:notifications, :project_chat_id)
    add_unique_index unless index_name_exists?(:notifications, INDEX_NAME)
  end

  def down
    remove_index :notifications, name: INDEX_NAME if index_name_exists?(:notifications, INDEX_NAME)
    remove_column :notifications, :project_chat_id if column_exists?(:notifications, :project_chat_id)
  end

  private

  def mysql?
    connection.adapter_name.match?(/mysql/i)
  end

  def add_project_chat_column
    return add_column(:notifications, :project_chat_id, :bigint) unless mysql?

    execute "ALTER TABLE notifications ADD COLUMN project_chat_id bigint NULL, ALGORITHM=INSTANT"
  end

  def add_unique_index
    return add_index(:notifications, [:project_chat_id, :visited_id], unique: true, name: INDEX_NAME) unless mysql?

    execute "ALTER TABLE notifications ADD UNIQUE INDEX #{INDEX_NAME} (project_chat_id, visited_id), ALGORITHM=INPLACE, LOCK=NONE"
  end
end
