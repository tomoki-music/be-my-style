class AddLeadHoursAndCustomMessageToEventDeadlineReminders < ActiveRecord::Migration[6.1]
  # 列の追加だけで既存行の値は書き換えない(有効・無効・送信状態・送信予定はそのまま)。
  # 既定値 12 により、既存行と、デプロイ中(マイグレーション後〜Puma再起動前)に旧コードが
  # 書き込んだ行も「12時間前・自動生成文」として扱われる。
  def change
    # 締め切りの何時間前に送るか。
    add_column :event_deadline_reminders, :lead_hours, :integer, null: false, default: 12
    # 主催者が編集した本文(空なら自動生成)。
    add_column :event_deadline_reminders, :custom_message, :text
    # armed_deadline を記録した時点の送信タイミング。現在の lead_hours と一致しない限り送らない。
    add_column :event_deadline_reminders, :armed_lead_hours, :integer, null: false, default: 12
    # 配信開始時に確定した件名・本文・配信方法(JSON)。送信中に設定が変わっても受信者ごとに混在させない。
    add_column :event_deadline_reminders, :message_snapshot, :text
  end
end
