class AddIndexToEventsEventEndTime < ActiveRecord::Migration[6.1]
  # PerformanceHistory::ExperiencedCustomersQuery / ProfileQueryが、終了済みイベント
  # (event_end_time <= now)を都度動的に絞り込むため、検索性能のためインデックスを追加する。
  def change
    add_index :events, :event_end_time
  end
end
