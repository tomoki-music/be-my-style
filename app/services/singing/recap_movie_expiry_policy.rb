module Singing
  class RecapMovieExpiryPolicy
    RETENTION_DAYS_BY_PLAN = {
      "free"    => 30,
      "light"   => 60,
      "core"    => 180,
      "premium" => nil   # nil = 無期限
    }.freeze

    DEFAULT_RETENTION_DAYS = 30

    # Returns the expires_at datetime for a given customer, or nil (premium = 無期限).
    def self.expires_at_for(customer)
      days = RETENTION_DAYS_BY_PLAN.fetch(customer.plan, DEFAULT_RETENTION_DAYS)
      return nil if days.nil?

      days.days.from_now
    end

    # Returns the retention days label for display (e.g. "30日", "無期限").
    def self.retention_label_for(customer)
      days = RETENTION_DAYS_BY_PLAN.fetch(customer.plan, DEFAULT_RETENTION_DAYS)
      days.nil? ? "無期限" : "#{days}日"
    end
  end
end
