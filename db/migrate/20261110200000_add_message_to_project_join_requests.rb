require_relative "../../lib/migration_lock_wait_timeout"

class AddMessageToProjectJoinRequests < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # 参加申請に添える任意のメッセージ。既存の申請は NULL(メッセージなし)のまま扱う。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_column :project_join_requests, :message, :text unless column_exists?(:project_join_requests, :message)
  end

  def down
    remove_column :project_join_requests, :message if column_exists?(:project_join_requests, :message)
  end
end
