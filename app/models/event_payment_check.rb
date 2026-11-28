# 当日受付の集金チェック票の1行(イベント×会員)。集金状況の記録だけを持ち、
# エントリー・参加人数・参加費の計算には使わない。
class EventPaymentCheck < ApplicationRecord
  belongs_to :event
  belongs_to :customer
  belongs_to :updated_by, class_name: "Customer", foreign_key: :updated_by_customer_id, optional: true

  validates :customer_id, uniqueness: { scope: :event_id }
  validates :collected, inclusion: { in: [true, false] }
end
