module Singing
  class MonthlyWrappedBuilder
    Result = Struct.new(
      :year,
      :month,
      :diagnosis_count,
      :active_days_count,
      :monthly_xp,
      :growth_type,
      :singer_rank,
      :most_improved_label,
      :most_improved_delta,
      :wrapped_message,
      :coach_reflection,
      :has_wrapped,
      keyword_init: true
    )

    def self.call(customer, year: Date.current.year, month: Date.current.month)
      new(customer, year: year, month: month).call
    end

    def initialize(customer, year:, month:)
      @customer = customer
      @year     = year
      @month    = month
    end

    def call
      return empty_result if @customer.nil?

      range_start = Time.zone.local(@year, @month, 1).beginning_of_month
      range_end   = range_start.end_of_month

      diagnoses = @customer.singing_diagnoses
                           .completed
                           .where.not(overall_score: nil)
                           .where(created_at: range_start..range_end)
                           .order(created_at: :asc, id: :asc)
                           .to_a

      return empty_result if diagnoses.empty?

      comparison  = Singing::MonthlyGrowthComparisonAnalyzer.call(@customer, year: @year, month: @month)
      growth_type = Singing::GrowthTypeAnalyzer.call(@customer)
      narrator    = Singing::MonthlyWrappedNarrator.call(
        customer_id:         @customer.id,
        year:                @year,
        month:               @month,
        personality:         @customer.singing_coach_personality,
        diagnosis_count:     diagnoses.size,
        most_improved_label: comparison.most_improved_label,
        most_improved_delta: comparison.most_improved_delta
      )

      Result.new(
        year:                @year,
        month:               @month,
        diagnosis_count:     diagnoses.size,
        active_days_count:   count_active_days(diagnoses),
        monthly_xp:          estimate_monthly_xp(diagnoses),
        growth_type:         growth_type,
        singer_rank:         @customer.singer_rank,
        most_improved_label: comparison.most_improved_label,
        most_improved_delta: comparison.most_improved_delta,
        wrapped_message:     narrator[:wrapped_message],
        coach_reflection:    narrator[:coach_reflection],
        has_wrapped:         true
      )
    end

    private

    def count_active_days(diagnoses)
      diagnoses.map { |d| d.created_at.to_date }.uniq.size
    end

    # XP履歴テーブルがないため、診断回数 × 50 の暫定推定値を使用
    def estimate_monthly_xp(diagnoses)
      diagnoses.size * 50
    end

    def empty_result
      Result.new(
        year:                @year,
        month:               @month,
        diagnosis_count:     0,
        active_days_count:   0,
        monthly_xp:          0,
        growth_type:         nil,
        singer_rank:         nil,
        most_improved_label: nil,
        most_improved_delta: nil,
        wrapped_message:     nil,
        coach_reflection:    nil,
        has_wrapped:         false
      )
    end
  end
end
