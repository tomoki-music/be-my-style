require_relative "../../lib/migration_lock_wait_timeout"

class CreateEventPaymentChecks < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # 当日受付の「集金チェック票」。会員ごと・イベントごとに集金済みかどうかだけを記録する。
  # エントリー・参加人数・参加費の計算(join_part_customers を見る)とは独立したテーブルにして、
  # チェック操作がそれらへ影響しないようにする。未集金へ戻した行も残し、最後に変更した人と日時を保つ。
  #
  # 途中で失敗しても再実行できるよう、テーブル・索引・外部キーの有無を確認してから作る(MySQL の DDL は巻き戻らない)。
  def up
    unless table_exists?(:event_payment_checks)
      create_table :event_payment_checks do |t|
        t.bigint :event_id, null: false
        t.bigint :customer_id, null: false
        t.boolean :collected, null: false, default: false
        t.bigint :updated_by_customer_id
        t.timestamps
      end
    end
    unless index_exists?(:event_payment_checks, [:event_id, :customer_id])
      add_index :event_payment_checks, [:event_id, :customer_id], unique: true
    end
    add_index :event_payment_checks, :customer_id unless index_exists?(:event_payment_checks, :customer_id)
    unless index_exists?(:event_payment_checks, :updated_by_customer_id)
      add_index :event_payment_checks, :updated_by_customer_id
    end
    unless foreign_key_exists?(:event_payment_checks, :events)
      add_foreign_key :event_payment_checks, :events, on_delete: :cascade
    end
    unless foreign_key_exists?(:event_payment_checks, :customers, column: :customer_id)
      add_foreign_key :event_payment_checks, :customers, column: :customer_id
    end
    unless foreign_key_exists?(:event_payment_checks, :customers, column: :updated_by_customer_id)
      add_foreign_key :event_payment_checks, :customers, column: :updated_by_customer_id, on_delete: :nullify
    end
  end

  def down
    drop_table :event_payment_checks if table_exists?(:event_payment_checks)
  end
end
