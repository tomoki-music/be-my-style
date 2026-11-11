require_relative "../../lib/migration_lock_wait_timeout"

class AddPinnedAtToProjectThreads < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # スレッドを固定した日時。NULL = 固定なし(既存のスレッドはすべて固定なしになる)。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_column :project_threads, :pinned_at, :datetime unless column_exists?(:project_threads, :pinned_at)
  end

  def down
    remove_column :project_threads, :pinned_at if column_exists?(:project_threads, :pinned_at)
  end
end
