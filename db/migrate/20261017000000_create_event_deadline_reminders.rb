class CreateEventDeadlineReminders < ActiveRecord::Migration[6.1]
  def change
    # イベントの「曲リクエスト締め切り」「エントリー締め切り」の12時間前に送る
    # 自動リマインドの設定と、締め切り種別ごとの送信状態(1イベント×1種別=1行)。
    # 既存イベントには行を作らない(=無効扱い)ため、導入直後の一斉送信は起きない。
    create_table :event_deadline_reminders do |t|
      t.references :event, null: false, foreign_key: true, index: false
      # 0: request(曲リクエスト締め切り) / 1: entry(エントリー締め切り)
      t.integer :kind, null: false
      t.boolean :enabled, null: false, default: false
      # 0: mail / 1: chat(コミュニティチャット)
      t.integer :channel, null: false, default: 0
      # 送信してよい締め切り日時。有効化・締め切り変更の時点で送信予定(締め切り-12時間)が
      # まだ未来だった場合だけ締め切り値を記録する。現在の締め切りと一致しない限り送信しない。
      t.datetime :armed_deadline
      # armed_deadline を記録できなかった理由(画面表示用)
      t.integer :disarm_reason
      # 0: pending / 1: sending / 2: sent / 3: failed
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :sent_at
      t.integer :sent_channel
      t.datetime :sent_for_deadline
      t.references :chat_message, foreign_key: { on_delete: :nullify }
      t.integer :delivered_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.string :failure_reason
      t.timestamps
    end

    add_index :event_deadline_reminders, [:event_id, :kind], unique: true
    add_index :event_deadline_reminders, [:enabled, :status, :armed_deadline],
              name: "index_event_deadline_reminders_on_dispatch"
  end
end
