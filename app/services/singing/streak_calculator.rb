module Singing
  class StreakCalculator
    def self.call(customer, as_of_date: Time.zone.today)
      new(customer, as_of_date: as_of_date).call
    end

    def initialize(customer, as_of_date: Time.zone.today)
      @customer   = customer
      @as_of_date = as_of_date
    end

    def call
      # SQLのDATE()はUTC保存で日付ズレが起きるため、Rubyレベルでto_dateを使う
      dates = @customer.singing_diagnoses
                       .completed
                       .where(created_at: ..@as_of_date.end_of_day)
                       .pluck(:created_at)
                       .map(&:to_date)
                       .to_set

      count = 0
      date  = @as_of_date
      while dates.include?(date)
        count += 1
        date  -= 1.day
      end
      count
    end
  end
end
