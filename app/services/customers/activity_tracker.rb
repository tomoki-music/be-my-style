module Customers
  # ログイン済み Customer の「BeMyStyle を利用していた日時」を last_active_at へ記録する。
  # 補助機能なので軽量・低頻度に徹し、Redis や非同期 Job、追加ライブラリは使わない。
  #
  # スロットリングは二段構え:
  #   1. メモリ上の last_active_at が閾値より新しければ SQL を一切発行しない
  #   2. UPDATE 自体にも WHERE 条件を持たせ、複数タブ・同時アクセスでの重複更新を抑える
  #
  # 境界は「ちょうど15分前 = 更新対象」で Ruby 早期リターンと SQL WHERE を揃える。
  #   last_active_at > threshold        → 更新しない（15分以内）
  #   last_active_at <= threshold / NULL → 更新対象
  class ActivityTracker
    THROTTLE_INTERVAL = 15.minutes

    def self.touch(customer, now: Time.current)
      new(customer, now: now).touch
    end

    def initialize(customer, now: Time.current)
      @customer = customer
      @now = now
    end

    def touch
      return if @customer.blank?
      return if @customer.is_deleted?

      threshold = @now - THROTTLE_INTERVAL
      current = @customer.last_active_at
      return if current.present? && current > threshold

      updated_count = Customer
        .where(id: @customer.id)
        .where("last_active_at IS NULL OR last_active_at <= ?", threshold)
        .update_all(last_active_at: @now)

      # DB で実際に更新できたときだけメモリ上の値も合わせる。
      # 同時アクセスで 0 件更新になった場合は誤った日時を代入しない。
      @customer.last_active_at = @now if updated_count.positive?
    end
  end
end
