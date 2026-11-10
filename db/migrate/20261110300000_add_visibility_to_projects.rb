require_relative "../../lib/migration_lock_wait_timeout"

class AddVisibilityToProjects < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # プロジェクトの公開範囲。0 = 通常公開(一覧・検索に出す)、1 = 限定公開(一覧・検索に出さず、URL からだけ開ける)。
  # 既存のプロジェクトは既定値 0 で通常公開のまま扱う。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_column :projects, :visibility, :integer, default: 0, null: false unless column_exists?(:projects, :visibility)
  end

  def down
    remove_column :projects, :visibility if column_exists?(:projects, :visibility)
  end
end
