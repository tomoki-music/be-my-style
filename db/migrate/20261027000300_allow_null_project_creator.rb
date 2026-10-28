require_relative "../../lib/migration_lock_wait_timeout"

class AllowNullProjectCreator < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # プロジェクト作成者の会員データを完全削除しても、プロジェクトとほかの参加者の会話を残す(作成者欄だけ NULL にする)。
  # 管理はコミュニティ運営者・admin が引き続き行える(BusinessAccess#business_project_manager?)。
  # 既存行・旧コードの書き込み(常に作成者あり)には影響しない。外部キーはそのまま残す。
  def up
    change_column_null :projects, :customer_id, true
  end

  def down
    change_column_null :projects, :customer_id, false
  end
end
