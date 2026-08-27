class EntryInvitation < ApplicationRecord
  # 同一イベント・同一曲・同一パート・同一Customerへの再送を許可する最短間隔。
  # これより新しい送信実績があれば「依頼済み」として再送しない。
  RESEND_INTERVAL = 24.hours

  belongs_to :event
  belongs_to :song
  belongs_to :join_part
  # 受信者(エントリー依頼を受け取る経験者)
  belongs_to :customer
  # 送信者(管理者/コミュニティ管理権限者/イベント作成者)
  belongs_to :requested_by_customer, class_name: "Customer"

  # pending: レコード作成済み・ジョブ投入済みで配信待ち
  # delivered: メール配信成功
  # failed: メール配信失敗(failure_reasonに理由)
  # skipped: 非本番環境などで実送信をスキップ
  enum status: { pending: 0, delivered: 1, failed: 2, skipped: 3 }

  scope :recent_first, -> { order(sent_at: :desc) }

  # 直近 RESEND_INTERVAL 以内に送信済み(=いま再送してはいけない)か。
  def within_resend_window?(now: Time.current)
    sent_at.present? && sent_at > now - RESEND_INTERVAL
  end
end
