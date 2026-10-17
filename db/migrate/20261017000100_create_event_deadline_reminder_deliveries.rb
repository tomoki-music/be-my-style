class CreateEventDeadlineReminderDeliveries < ActiveRecord::Migration[6.1]
  def change
    # メール配信の受信者単位の送信履歴。(リマインド, 受信者) につき1行だけ作れるよう
    # 一意制約を張り、定期実行の再実行・並列実行でも同じ人へ2通送らないようにする。
    create_table :event_deadline_reminder_deliveries do |t|
      t.references :event_deadline_reminder, null: false, foreign_key: true, index: false
      t.references :customer, null: false, foreign_key: { on_delete: :cascade }
      # 0: sending / 1: delivered / 2: failed / 3: skipped
      t.integer :status, null: false, default: 0
      t.datetime :delivered_at
      t.string :failure_reason
      t.timestamps
    end

    add_index :event_deadline_reminder_deliveries, [:event_deadline_reminder_id, :customer_id],
              unique: true, name: "index_event_deadline_reminder_deliveries_on_reminder_customer"
  end
end
