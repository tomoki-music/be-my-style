module Singing
  class GrowthFeedSummaryBuilder
    Summary = Struct.new(
      :weekly_singer_count,
      :weekly_first_diagnosis_count,
      :weekly_cheer_count,
      :weekly_challenge_completion_count,
      :growth_type_highlights,
      keyword_init: true
    )

    GrowthTypeHighlight = Struct.new(
      :icon,
      :label,
      :message,
      keyword_init: true
    )

    def self.call(feed_items: nil)
      new(feed_items: feed_items).call
    end

    def initialize(feed_items: nil)
      @feed_items = feed_items
    end

    def call
      Summary.new(
        weekly_singer_count: weekly_singer_count,
        weekly_first_diagnosis_count: weekly_first_diagnosis_count,
        weekly_cheer_count: weekly_cheer_count,
        weekly_challenge_completion_count: weekly_challenge_completion_count,
        growth_type_highlights: growth_type_highlights
      )
    end

    private

    def week_range
      @week_range ||= Time.current.beginning_of_week..Time.current.end_of_week
    end

    def weekly_singer_count
      SingingDiagnosis.completed
                      .where(created_at: week_range)
                      .distinct
                      .count(:customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def weekly_first_diagnosis_count
      SingingDiagnosis.completed
                      .where(customer_id: weekly_customer_ids)
                      .group(:customer_id)
                      .minimum(:created_at)
                      .values
                      .count { |first_at| first_at.in?(week_range) }
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def weekly_cheer_count
      return 0 unless defined?(SingingCheerReaction)

      SingingCheerReaction.where(created_at: week_range).count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def weekly_challenge_completion_count
      weekly_five_diagnosis_customers + weekly_streak_customers
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def weekly_five_diagnosis_customers
      SingingDiagnosis.completed
                      .where(created_at: week_range)
                      .group(:customer_id)
                      .having("COUNT(*) >= 5")
                      .count
                      .size
    end

    def weekly_streak_customers
      Customer.where(id: weekly_customer_ids).count do |customer|
        Singing::StreakCalculator.call(customer) >= 7
      end
    end

    def weekly_customer_ids
      @weekly_customer_ids ||= SingingDiagnosis.completed
                                              .where(created_at: week_range)
                                              .distinct
                                              .pluck(:customer_id)
    end

    def growth_type_highlights
      source_items = Array(@feed_items).select { |item| weekly_customer_ids.include?(item.customer.id) }
      highlights =
        if source_items.present?
          source_items.first(8).filter_map { |item| highlight_for(item.growth_type) }
        else
          Customer.where(id: weekly_customer_ids).first(8).filter_map do |customer|
            highlight_for(Singing::GrowthTypeAnalyzer.call(customer))
          end
        end

      highlights.first(3)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def highlight_for(growth_type)
      return nil if growth_type.nil?

      GrowthTypeHighlight.new(
        icon: growth_type.icon,
        label: growth_type.label,
        message: "#{growth_type.label} が挑戦中"
      )
    end
  end
end
