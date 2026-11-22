require_relative "../../lib/migration_lock_wait_timeout"

class CreateBusinessSignupInvitations < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # 招待用URL(コミュニティ・プロジェクトの詳細画面)を未ログインで開いて新規登録した人の「招待先」。
  # 確認メールを別のブラウザで開いてもオンボーディング完了後に招待先へ案内できるよう、セッションではなく会員に紐づけて持つ。
  # 1人1件。オンボーディング完了時に取り出して削除する。
  def up
    return if table_exists?(:business_signup_invitations)

    create_table :business_signup_invitations do |t|
      t.references :customer, null: false, foreign_key: true, index: { unique: true }
      t.string :target_type, null: false, limit: 20
      t.bigint :target_id, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
  end

  def down
    drop_table :business_signup_invitations if table_exists?(:business_signup_invitations)
  end
end
