module Singing
  class GrowthFeedBuilder
    FEED_LIMIT  = 20
    WINDOW_DAYS = 30

    FeedItem = Struct.new(
      :customer,
      :growth_type,
      :growth_circle_badge,
      :completed_challenge_keys,
      :most_improved_label,
      :most_improved_delta,
      :streak_days,
      :reaction_count,
      :feed_type,
      :feed_icon,
      :feed_label,
      :headline,
      :milestones,
      :shared_at,
      keyword_init: true
    )

    Milestone = Struct.new(
      :icon,
      :label,
      :message,
      keyword_init: true
    )

    def self.call(limit: FEED_LIMIT)
      new(limit: limit).call
    end

    def initialize(limit: FEED_LIMIT)
      @limit = limit
    end

    def call
      active_customers.filter_map { |customer| build_item(customer) }
                      .sort_by { |item| -item.shared_at.to_i }
                      .first(@limit)
    end

    private

    def active_customers
      Customer
        .joins(:singing_diagnoses)
        .where(
          singing_diagnoses: {
            status:     :completed,
            created_at: window_range
          }
        )
        .where.not(singing_diagnoses: { overall_score: nil })
        .distinct
        .includes(:singing_diagnoses)
    end

    def window_range
      WINDOW_DAYS.days.ago.beginning_of_day..Time.current
    end

    def completed_challenges_for(customer, streak)
      keys = []
      keys << :streak_7 if streak >= 7

      now = Time.current
      week_count = customer.singing_diagnoses
                           .completed
                           .where(created_at: now.beginning_of_week..now.end_of_week)
                           .count
      keys << :diagnosis_5 if week_count >= 5

      keys
    end

    def build_item(customer)
      recent = customer.singing_diagnoses
                       .completed
                       .where.not(overall_score: nil)
                       .where(created_at: window_range)
                       .order(created_at: :desc, id: :desc)
                       .first
      return nil unless recent

      year  = recent.created_at.year
      month = recent.created_at.month

      comparison             = Singing::MonthlyGrowthComparisonAnalyzer.call(customer, year: year, month: month)
      growth_type            = Singing::GrowthTypeAnalyzer.call(customer)
      streak                 = Singing::StreakCalculator.call(customer)
      growth_circle_badge    = Singing::GrowthCircleBadgeAnalyzer.call(customer).first
      completed_challenge_keys = completed_challenges_for(customer, streak)

      milestones = milestones_for(customer, recent, streak, growth_type, completed_challenge_keys)

      FeedItem.new(
        customer:                customer,
        growth_type:             growth_type,
        growth_circle_badge:     growth_circle_badge,
        completed_challenge_keys: completed_challenge_keys,
        most_improved_label:     comparison&.most_improved_label,
        most_improved_delta:     comparison&.most_improved_delta,
        streak_days:             streak,
        reaction_count:          reaction_count_for(customer),
        feed_type:               feed_type(completed_challenge_keys, milestones),
        feed_icon:               feed_icon(completed_challenge_keys, milestones),
        feed_label:              feed_label(completed_challenge_keys, milestones),
        headline:                headline_for(customer, comparison, milestones),
        milestones:              milestones,
        shared_at:               recent.created_at
      )
    end

    def reaction_count_for(customer)
      return 0 unless defined?(SingingCheerReaction)

      SingingCheerReaction.where(target_customer: customer).count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def milestones_for(customer, recent, streak, growth_type, completed_challenge_keys)
      milestones = []
      count = diagnosis_count(customer)

      milestones << Milestone.new(icon: "🎤", label: "First Song", message: "初めての診断を完了しました") if count == 1
      milestones << Milestone.new(icon: "🔥", label: "7 Days", message: "7日連続で歌を残しています") if streak >= 7
      milestones << Milestone.new(icon: "🚀", label: "Best Update", message: "自己ベストを更新しました") if best_score_update?(customer, recent)
      milestones << Milestone.new(icon: growth_type.icon, label: growth_type.label, message: "#{growth_type.label} の仲間が増えました") if count >= 2 && growth_type
      milestones << Milestone.new(icon: "🤝", label: "Cheer", message: "初めて応援を送りました") if first_cheer?(customer)

      if completed_challenge_keys.present? && milestones.none? { |milestone| milestone.label == "Challenge" }
        milestones << Milestone.new(icon: "🎯", label: "Challenge", message: "今週のチャレンジを達成しました")
      end

      milestones.first(3)
    end

    def diagnosis_count(customer)
      customer.singing_diagnoses.completed.where.not(overall_score: nil).count
    rescue NoMethodError
      0
    end

    def best_score_update?(customer, recent)
      return false if recent.overall_score.nil?

      previous_best = customer.singing_diagnoses
                              .completed
                              .where.not(overall_score: nil)
                              .where("created_at < ?", recent.created_at)
                              .maximum(:overall_score)

      previous_best.present? && recent.overall_score > previous_best
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      false
    end

    def first_cheer?(customer)
      return false unless defined?(SingingCheerReaction)

      customer.singing_cheer_reactions.count == 1
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      false
    end

    def feed_type(completed_challenge_keys, milestones)
      return :challenge if completed_challenge_keys.present?
      return :milestone if milestones.any? { |milestone| ["First Song", "Best Update", "7 Days"].include?(milestone.label) }
      return :community if milestones.any? { |milestone| milestone.label.exclude?("Cheer") }
      return :cheer if milestones.any? { |milestone| milestone.label == "Cheer" }

      :diagnosis
    end

    def feed_icon(completed_challenge_keys, milestones)
      case feed_type(completed_challenge_keys, milestones)
      when :challenge then "🎯"
      when :milestone then "🚀"
      when :community then "🤝"
      when :cheer then "🔥"
      else "🎤"
      end
    end

    def feed_label(completed_challenge_keys, milestones)
      case feed_type(completed_challenge_keys, milestones)
      when :challenge then "Challenge"
      when :milestone then "Milestone"
      when :community then "Community"
      when :cheer then "Cheer"
      else "Diagnosis"
      end
    end

    def headline_for(customer, comparison, milestones)
      milestone = milestones.first
      return milestone.message if milestone

      if comparison&.most_improved_label && comparison&.most_improved_delta
        "#{comparison.most_improved_label} +#{comparison.most_improved_delta.round(1)}"
      else
        "#{customer.name}さんが今日の歌を残しました"
      end
    end
  end
end
