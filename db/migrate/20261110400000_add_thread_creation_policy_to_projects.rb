require_relative "../../lib/migration_lock_wait_timeout"

class AddThreadCreationPolicyToProjects < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # スレッドを作成できる人。0 = 管理者・オーナーのみ、1 = 運営者まで、2 = 参加メンバー全員。
  # 既存のプロジェクトも既定値 0(管理者・オーナーのみ)になる。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_column :projects, :thread_creation_policy, :integer, default: 0, null: false unless column_exists?(:projects, :thread_creation_policy)
  end

  def down
    remove_column :projects, :thread_creation_policy if column_exists?(:projects, :thread_creation_policy)
  end
end
