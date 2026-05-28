module Singing
  class ShareImageBuilder
    ShareCard = Struct.new(
      :year,
      :month,
      :growth_type_key,
      :growth_type_label,
      :growth_type_icon,
      :singer_rank_label,
      :singer_rank_icon,
      :singer_rank_level,
      :diagnosis_count,
      :active_days,
      :streak,
      :most_improved_label,
      :most_improved_delta,
      :wrapped_message,
      :coach_reflection,
      :has_premium_features,
      :has_data,
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
      return empty_card if @customer.nil?

      wrapped     = Singing::MonthlyWrappedBuilder.call(@customer, year: @year, month: @month)
      growth_type = wrapped.growth_type || Singing::GrowthTypeAnalyzer.call(@customer)
      rank        = @customer.singer_rank
      streak      = Singing::StreakCalculator.call(@customer, as_of_date: Date.current)
      premium     = @customer.has_feature?(:singing_monthly_wrapped_share_image)

      ShareCard.new(
        year:                 @year,
        month:                @month,
        growth_type_key:      growth_type&.type_key,
        growth_type_label:    growth_type&.label,
        growth_type_icon:     growth_type&.icon,
        singer_rank_label:    rank&.label,
        singer_rank_icon:     rank&.icon,
        singer_rank_level:    rank&.level,
        diagnosis_count:      wrapped.diagnosis_count,
        active_days:          wrapped.active_days_count,
        streak:               streak,
        most_improved_label:  wrapped.most_improved_label,
        most_improved_delta:  wrapped.most_improved_delta,
        wrapped_message:      wrapped.wrapped_message,
        coach_reflection:     premium ? wrapped.coach_reflection : nil,
        has_premium_features: premium,
        has_data:             wrapped.has_wrapped
      )
    end

    private

    def empty_card
      ShareCard.new(
        year: @year, month: @month,
        growth_type_key: nil, growth_type_label: nil, growth_type_icon: nil,
        singer_rank_label: nil, singer_rank_icon: nil, singer_rank_level: nil,
        diagnosis_count: 0, active_days: 0, streak: 0,
        most_improved_label: nil, most_improved_delta: nil,
        wrapped_message: nil, coach_reflection: nil,
        has_premium_features: false, has_data: false
      )
    end
  end
end
