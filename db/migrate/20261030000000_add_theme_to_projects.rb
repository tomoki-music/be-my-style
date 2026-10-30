require_relative "../../lib/migration_lock_wait_timeout"

class AddThemeToProjects < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # プロジェクトの話題・活動を1行で伝える任意項目(最大100文字)。既存行は未設定(NULL)のまま使える。
  # 取りやめた goal / deadline の列とデータはそのまま残し、テーマへの転記もしない。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_column :projects, :theme, :string, limit: 100 unless column_exists?(:projects, :theme)
  end

  def down
    remove_column :projects, :theme if column_exists?(:projects, :theme)
  end
end
