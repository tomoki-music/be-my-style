module Singing
  class StreakCalculator
    def self.call(customer, as_of_date: Time.zone.today, diagnoses: nil)
      new(customer, as_of_date: as_of_date, diagnoses: diagnoses).call
    end

    def initialize(customer, as_of_date: Time.zone.today, diagnoses: nil)
      @customer   = customer
      @as_of_date = as_of_date
      @diagnoses_scope = diagnoses || customer&.singing_diagnoses
    end

    def call
      # SQLのDATE()はUTC保存で日付ズレが起きるため、Rubyレベルでto_dateを使う
      dates = @diagnoses_scope
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
