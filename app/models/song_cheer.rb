# 楽曲の「応援する📣」。演奏エントリー(JoinPartCustomer)とは別テーブルにしているので、
# 成立判定・募集パート・演奏実績・エントリー依頼候補・参加人数/料金の集計には混ざらない。
class SongCheer < ApplicationRecord
  belongs_to :song
  belongs_to :customer

  validates :customer_id, uniqueness: { scope: :song_id, message: "はこの曲をすでに応援しています" }
end
