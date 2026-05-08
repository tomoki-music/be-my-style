module Learning
  class MonthlyReportGenerator
    def self.call(customer, month = Date.current.prev_month.beginning_of_month)
      new(customer, month).generate
    end

    def initialize(customer, month)
      @customer = customer
      @month    = month
      @range    = month..(month.end_of_month)
    end

    def generate
      report = LearningMonthlyReport.for_month(@customer, @month)
      report.assign_attributes(
        total_students:           active_students.count,
        total_progress_logs:      logs_in_month.count,
        total_achieved_trainings: trainings_achieved_in_month.count,
        avg_achievement_rate:     avg_rate
      )
      report.save!
      report
    end

    private

    def active_students
      @active_students ||= @customer.learning_students.active
    end

    def logs_in_month
      @customer.learning_progress_logs.where(practiced_on: @range)
    end

    def trainings_achieved_in_month
      @customer.learning_student_trainings.where(status: "achieved", updated_at: @range)
    end

    def avg_rate
      return 0.0 if active_students.empty?

      rates = active_students.map(&:achievement_rate)
      (rates.sum / rates.size).round(2)
    end
  end
end
