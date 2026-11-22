require_relative "../../lib/migration_lock_wait_timeout"

class AddWithdrawnAtToCustomers < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # 本人が退会を確定した日時。NULL = 本人による退会なし(既存の会員はすべて NULL)。
  # 管理画面の「退会」(is_deleted のみ)と区別し、本人退会したアカウントは復元させないために使う。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_column :customers, :withdrawn_at, :datetime unless column_exists?(:customers, :withdrawn_at)
  end

  def down
    remove_column :customers, :withdrawn_at if column_exists?(:customers, :withdrawn_at)
  end
end
