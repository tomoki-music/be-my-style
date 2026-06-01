module Singing
  class EncouragementSummaryBuilder
    WINDOW_DAYS = 7

    Result = Struct.new(
      :total_count,
      :unique_cheerleaders,
      :counts_by_type,
      :top_reaction_type,
      :summary_message,
      :has_summary,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return empty_result if @customer.nil?

      reactions = @customer.received_singing_cheer_reactions
                           .where(created_at: window_range)

      total = reactions.count
      return empty_result if total.zero?

      unique_givers = reactions.distinct.count(:customer_id)
      counts        = counts_by_type(reactions)
      top_type      = counts.max_by { |_, c| c }&.first

      Result.new(
        total_count:         total,
        unique_cheerleaders: unique_givers,
        counts_by_type:      counts,
        top_reaction_type:   top_type,
        summary_message:     build_message(total, unique_givers, top_type),
        has_summary:         true
      )
    end

    private

    def window_range
      WINDOW_DAYS.days.ago.beginning_of_day..Time.current
    end

    def counts_by_type(reactions)
      SingingCheerReaction::REACTION_TYPES.each_with_object({}) do |type, hash|
        hash[type] = reactions.where(reaction_type: type).count
      end
    end

    def build_message(total, unique_givers, top_type)
      top_emoji = top_type ? SingingCheerReaction.emoji_for(top_type) : ""
      top_label = top_type ? SingingCheerReaction.label_for(top_type) : ""

      "今週は #{unique_givers}人から #{total}件の応援が届きました。" \
        "最も多かったのは #{top_emoji}「#{top_label}」です。"
    end

    def empty_result
      Result.new(
        total_count:         0,
        unique_cheerleaders: 0,
        counts_by_type:      SingingCheerReaction::REACTION_TYPES.index_with(0),
        top_reaction_type:   nil,
        summary_message:     nil,
        has_summary:         false
      )
    end
  end
end
