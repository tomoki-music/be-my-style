class LearningMonthlyReport < ApplicationRecord
  belongs_to :customer

  validates :report_month, presence: true, uniqueness: { scope: :customer_id }

  scope :recent_first, -> { order(report_month: :desc) }

  def self.for_month(customer, month = Date.current.prev_month.beginning_of_month)
    find_or_initialize_by(customer: customer, report_month: month)
  end

  def month_label
    report_month.strftime("%Y年%-m月")
  end
end
