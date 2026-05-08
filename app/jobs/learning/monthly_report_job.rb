module Learning
  class MonthlyReportJob < ApplicationJob
    queue_as :default

    def perform(month_str = nil)
      month = month_str ? Date.parse(month_str).beginning_of_month : Date.current.prev_month.beginning_of_month

      Customer.joins(:learning_students).distinct.find_each do |customer|
        Learning::MonthlyReportGenerator.call(customer, month)
      rescue => e
        Rails.logger.error "[Learning::MonthlyReportJob] customer_id=#{customer.id} error=#{e.message}"
      end
    end
  end
end
