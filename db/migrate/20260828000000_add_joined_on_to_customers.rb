class AddJoinedOnToCustomers < ActiveRecord::Migration[6.1]
  # 既存ユーザーの joined_on を「created_at を Tokyo 時間の日付へ変換した値」で埋める。
  # 本番/開発は MySQL・テストは SQLite でアダプターが異なるため、
  # `DATE(created_at + INTERVAL 9 HOUR)` のような MySQL 専用 SQL は使わず、
  # Tokyo 変換は Ruby 側で行いアダプター非依存にする。
  # また現在の Customer モデル（バリデーション/コールバック/デフォルト値）に依存させないため、
  # customers テーブルだけを触る軽量な専用クラスを使う。
  class MigrationCustomer < ActiveRecord::Base
    self.table_name = "customers"
  end

  BACKFILL_BATCH_SIZE = 1_000

  def up
    add_column :customers, :joined_on, :date

    MigrationCustomer.reset_column_information
    backfill_joined_on!

    remaining = MigrationCustomer.where(joined_on: nil).count
    if remaining.positive?
      raise ActiveRecord::MigrationError,
            "joined_on が NULL の customers が #{remaining} 件残っているため NOT NULL 制約を追加できません"
    end

    change_column_null :customers, :joined_on, false
  end

  def down
    # 注意: この down はカラムを削除するだけで、バックフィルした
    # joined_on の値は失われる（created_at からの再計算は再度 up が必要）。
    remove_column :customers, :joined_on
  end

  private

  # joined_on が NULL のレコードを 1 バッチずつ埋める。
  # 各バッチで必ず 1 件以上を NULL でない値に更新するため NULL 件数は単調減少し、
  # 空バッチ（= 残り 0 件）で必ずループが終了する（無限ループにならない）。
  def backfill_joined_on!
    loop do
      batch = MigrationCustomer.where(joined_on: nil).limit(BACKFILL_BATCH_SIZE).to_a
      break if batch.empty?

      batch.group_by { |record| record.created_at.in_time_zone("Asia/Tokyo").to_date }
           .each do |joined_on, records|
        MigrationCustomer.where(id: records.map(&:id)).update_all(joined_on: joined_on)
      end
    end
  end
end
