require_relative "../../lib/migration_lock_wait_timeout"

class CreateBusinessNotificationSettings < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # Business(NAKAMA)の通知設定。音楽側と共用の customers.confirm_mail とは別に持ち、Business 側の変更を音楽側へ波及させない。
  # 行が無い会員は従来どおり confirm_mail(メール)・オン(画面内)として扱うので、既存会員のデータ移行はしない。
  def up
    return if table_exists?(:business_notification_settings)

    create_table :business_notification_settings do |t|
      t.references :customer, null: false, foreign_key: true, index: { unique: true }
      t.boolean :email_enabled, null: false, default: true
      t.boolean :in_app_enabled, null: false, default: true
      t.timestamps
    end
  end

  def down
    drop_table :business_notification_settings if table_exists?(:business_notification_settings)
  end
end
