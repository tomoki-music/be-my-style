require_relative "../../lib/migration_lock_wait_timeout"

class AddHiddenInAppToNotifications < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # Business の「画面内の通知」をオフにした会員宛ての通知は、レコードは作って(スレッド投稿のメール送信・重複防止の起点のため)
  # ベル・通知一覧には出さない。既存の通知はすべて false(表示)のまま。
  #
  # notifications は全ドメイン共通の大きな表なので、MySQL では ALGORITHM=INSTANT を明示し、使えない場合は表をコピーせずに失敗させる。
  # 開始・終了時の短い排他メタデータロック待ちは MigrationLockWaitTimeout で5秒に制限している。
  def up
    return if column_exists?(:notifications, :hidden_in_app)
    return add_column(:notifications, :hidden_in_app, :boolean, null: false, default: false) unless mysql?

    execute "ALTER TABLE notifications ADD COLUMN hidden_in_app tinyint(1) NOT NULL DEFAULT 0, ALGORITHM=INSTANT"
  end

  def down
    remove_column :notifications, :hidden_in_app if column_exists?(:notifications, :hidden_in_app)
  end

  private

  def mysql?
    connection.adapter_name.match?(/mysql/i)
  end
end
