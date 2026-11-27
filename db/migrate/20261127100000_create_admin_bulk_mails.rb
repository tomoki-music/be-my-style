require_relative "../../lib/migration_lock_wait_timeout"

class CreateAdminBulkMails < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # 管理画面 TOP のメンバー一覧から送る「名前入り一括メール」。
  # - admin_bulk_mails: 1回の送信(件名・本文・送った管理者)。request_token を一意にし、確定ボタンの二重送信で
  #   同じ送信が2回作られないようにする。
  # - admin_bulk_mail_recipients: 宛先ごとの配信状態。(admin_bulk_mail_id, customer_id) を一意にし、同じ送信で
  #   同じ会員へ2通送らないようにする。メールアドレスそのものは保存せず、確認画面に出したアドレスの照合用
  #   ダイジェスト(email_digest, HMAC-SHA256)だけを持つ。送る直前に会員の今のアドレスと照らし、違えば送らない。
  # 会員を物理削除しても送信履歴の件数が変わらないよう、customer_id は外部キーで NULL にする。
  #
  # 途中で失敗しても再実行できるよう、テーブル・索引・外部キーの有無を確認してから作る(MySQL の DDL は巻き戻らない)。
  def up
    unless table_exists?(:admin_bulk_mails)
      create_table :admin_bulk_mails do |t|
        t.bigint :admin_id
        t.string :subject, null: false
        t.text :body, null: false
        t.string :request_token, null: false
        t.integer :recipients_count, null: false, default: 0
        t.timestamps
      end
    end
    add_index :admin_bulk_mails, :request_token, unique: true unless index_exists?(:admin_bulk_mails, :request_token)
    add_index :admin_bulk_mails, :admin_id unless index_exists?(:admin_bulk_mails, :admin_id)
    unless foreign_key_exists?(:admin_bulk_mails, :admins)
      add_foreign_key :admin_bulk_mails, :admins, on_delete: :nullify
    end

    unless table_exists?(:admin_bulk_mail_recipients)
      create_table :admin_bulk_mail_recipients do |t|
        t.bigint :admin_bulk_mail_id, null: false
        t.bigint :customer_id
        t.integer :status, null: false, default: 0
        t.string :email_digest, null: false
        t.string :failure_reason
        t.datetime :sent_at
        t.timestamps
      end
    end
    unless index_exists?(:admin_bulk_mail_recipients, [:admin_bulk_mail_id, :customer_id])
      add_index :admin_bulk_mail_recipients, [:admin_bulk_mail_id, :customer_id],
                unique: true, name: "index_admin_bulk_mail_recipients_on_mail_and_customer"
    end
    unless index_exists?(:admin_bulk_mail_recipients, :customer_id)
      add_index :admin_bulk_mail_recipients, :customer_id
    end
    unless foreign_key_exists?(:admin_bulk_mail_recipients, :admin_bulk_mails)
      add_foreign_key :admin_bulk_mail_recipients, :admin_bulk_mails, on_delete: :cascade
    end
    unless foreign_key_exists?(:admin_bulk_mail_recipients, :customers)
      add_foreign_key :admin_bulk_mail_recipients, :customers, on_delete: :nullify
    end
  end

  def down
    drop_table :admin_bulk_mail_recipients if table_exists?(:admin_bulk_mail_recipients)
    drop_table :admin_bulk_mails if table_exists?(:admin_bulk_mails)
  end
end
