# バンド出演枠への「このバンドを応援する📣」。曲への応援(SongCheer)とは独立していて、両方を使える。
# 演奏エントリー(JoinPartCustomer)とは別テーブルなので、参加人数・料金・成立判定には数えない。
class EventBandCheer < ApplicationRecord
  belongs_to :event_band
  belongs_to :customer

  validates :customer_id, uniqueness: { scope: :event_band_id, message: "はこのバンドをすでに応援しています" }
end
