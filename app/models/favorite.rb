class Favorite < ApplicationRecord
  belongs_to :customer
  belongs_to :activity

  # favorites には一意制約が無いため、登録はアプリ側で重複を防ぐ。
  validates :customer_id, uniqueness: { scope: :activity_id }

  # 記事の行をロックしてから登録済みか確かめて登録する。管理画面の一括追加
  # (Activities::AdminFavoriteAdder)も同じ行ロックを取るので、同時に処理されても重複しない。
  # 登録したときは Favorite、登録済みだったときは nil を返す。
  def self.add_unique(activity:, customer:)
    transaction do
      activity.lock!
      next nil if exists?(activity_id: activity.id, customer_id: customer.id)

      create!(activity: activity, customer: customer)
    end
  end
end
