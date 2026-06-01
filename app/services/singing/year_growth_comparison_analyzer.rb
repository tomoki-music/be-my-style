module Singing
  class YearGrowthComparisonAnalyzer
    SCORE_KEYS = %i[pitch_score rhythm_score expression_score overall_score].freeze

    SCORE_LABELS = {
      overall_score:    "総合スコア",
      pitch_score:      "音程",
      rhythm_score:     "リズム",
      expression_score: "表現力"
    }.freeze

    MONTH_NAMES = %w[1月 2月 3月 4月 5月 6月 7月 8月 9月 10月 11月 12月].freeze

    Milestone = Struct.new(:type, :label, :date, keyword_init: true)

    Result = Struct.new(
      :has_comparison,
      :diagnosis_count,
      :first_scores,
      :recent_scores,
      :deltas,
      :most_improved_key,
      :most_improved_label,
      :most_improved_delta,
      :max_streak,
      :first_diagnosis_date,
      :personal_best_score,
      :personal_best_date,
      :most_active_month,
      :most_active_month_count,
      :most_active_month_label,
      :milestones,
      keyword_init: true
    )

    def self.call(customer, year:)
      new(customer, year: year).call
    end

    def initialize(customer, year:)
      @customer = customer
      @year     = year
    end

    def call
      return no_data_result if @customer.nil?

      diagnoses = fetch_diagnoses
      return no_data_result if diagnoses.empty?

      first_group, recent_group = select_groups(diagnoses)
      first_scores  = average_scores(first_group)
      recent_scores = average_scores(recent_group)
      deltas        = compute_deltas(first_scores, recent_scores)
      best_key, best_delta = best_improvement(deltas)

      active_month = most_active_month_number(diagnoses)

      Result.new(
        has_comparison:          diagnoses.size >= 2,
        diagnosis_count:         diagnoses.size,
        first_scores:            first_scores,
        recent_scores:           recent_scores,
        deltas:                  deltas,
        most_improved_key:       best_key,
        most_improved_label:     best_key ? SCORE_LABELS[best_key] : nil,
        most_improved_delta:     best_delta,
        max_streak:              compute_max_streak(diagnoses),
        first_diagnosis_date:    diagnoses.first.created_at.to_date,
        personal_best_score:     personal_best_score(diagnoses),
        personal_best_date:      personal_best_date(diagnoses),
        most_active_month:       active_month,
        most_active_month_count: most_active_month_count_for(diagnoses, active_month),
        most_active_month_label: active_month ? MONTH_NAMES[active_month - 1] : nil,
        milestones:              build_milestones(diagnoses)
      )
    end

    private

    def fetch_diagnoses
      return [] if @customer.nil?

      year_start = Time.zone.local(@year, 1, 1).beginning_of_year
      year_end   = year_start.end_of_year

      @customer.singing_diagnoses
               .completed
               .where.not(overall_score: nil)
               .where(created_at: year_start..year_end)
               .order(created_at: :asc, id: :asc)
               .to_a
    end

    def select_groups(diagnoses)
      count = diagnoses.size
      if count >= 6
        [diagnoses.first(3), diagnoses.last(3)]
      else
        [[diagnoses.first], [diagnoses.last]]
      end
    end

    def average_scores(group)
      SCORE_KEYS.each_with_object({}) do |key, hash|
        values = group.map { |d| d.public_send(key) }.compact
        hash[key] = values.empty? ? nil : values.sum.to_f / values.size
      end
    end

    def compute_deltas(first_scores, recent_scores)
      SCORE_KEYS.each_with_object({}) do |key, hash|
        f = first_scores[key]
        r = recent_scores[key]
        hash[key] = (f && r) ? (r - f).round : nil
      end
    end

    def best_improvement(deltas)
      best_key   = nil
      best_delta = 0

      deltas.each do |key, delta|
        next if delta.nil?
        if delta > best_delta
          best_delta = delta
          best_key   = key
        end
      end

      [best_key, best_key ? best_delta : nil]
    end

    def compute_max_streak(diagnoses)
      dates = diagnoses.map { |d| d.created_at.to_date }.uniq.sort
      return 0 if dates.empty?
      return 1 if dates.size == 1

      max_streak  = 1
      curr_streak = 1
      dates.each_cons(2) do |prev, curr|
        if curr == prev + 1
          curr_streak += 1
          max_streak = [max_streak, curr_streak].max
        else
          curr_streak = 1
        end
      end
      max_streak
    end

    def personal_best_score(diagnoses)
      diagnoses.filter_map(&:overall_score).max
    end

    def personal_best_date(diagnoses)
      best = diagnoses.select(&:overall_score).max_by(&:overall_score)
      best&.created_at&.to_date
    end

    def most_active_month_number(diagnoses)
      diagnoses
        .group_by { |d| d.created_at.in_time_zone.month }
        .max_by { |_, group| group.size }
        &.first
    end

    def most_active_month_count_for(diagnoses, month)
      return nil if month.nil?

      diagnoses.count { |d| d.created_at.in_time_zone.month == month }
    end

    def build_milestones(diagnoses)
      milestones = []

      milestones << Milestone.new(
        type:  :first_diagnosis,
        label: "今年の初診断",
        date:  diagnoses.first.created_at.to_date
      )

      first_80 = diagnoses.find { |d| d.overall_score.to_i >= 80 }
      if first_80
        milestones << Milestone.new(
          type:  :first_80,
          label: "初めてOverall 80超え",
          date:  first_80.created_at.to_date
        )
      end

      best_diagnosis = diagnoses.select(&:overall_score).max_by(&:overall_score)
      if best_diagnosis && best_diagnosis.overall_score.to_i > 0
        milestones << Milestone.new(
          type:  :personal_best,
          label: "自己ベスト #{best_diagnosis.overall_score}点",
          date:  best_diagnosis.created_at.to_date
        )
      end

      milestones
    end

    def no_data_result
      Result.new(
        has_comparison:          false,
        diagnosis_count:         0,
        first_scores:            {},
        recent_scores:           {},
        deltas:                  {},
        most_improved_key:       nil,
        most_improved_label:     nil,
        most_improved_delta:     nil,
        max_streak:              0,
        first_diagnosis_date:    nil,
        personal_best_score:     nil,
        personal_best_date:      nil,
        most_active_month:       nil,
        most_active_month_count: nil,
        most_active_month_label: nil,
        milestones:              []
      )
    end
  end
end
