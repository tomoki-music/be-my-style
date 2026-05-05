module Singing
  class SeasonRankingAggregator
    CATEGORIES = {
      "overall" => :overall_score,
      "pitch" => :pitch_score,
      "rhythm" => :rhythm_score,
      "expression" => :expression_score
    }.freeze

    def initialize(season)
      @season = season
    end

    def call
      SingingSeasonRankingEntry.transaction do
        remove_existing_entries
        CATEGORIES.each_key { |category| create_entries_for(category) }
      end
    end

    private

    attr_reader :season

    def remove_existing_entries
      season.singing_season_ranking_entries
            .where(category: CATEGORIES.keys)
            .delete_all
    end

    def create_entries_for(category)
      score_attribute = CATEGORIES.fetch(category)

      ranked_diagnoses_for(score_attribute).each.with_index(1) do |diagnosis, rank|
        season.singing_season_ranking_entries.create!(
          customer: diagnosis.customer,
          singing_diagnosis: diagnosis,
          category: category,
          rank: rank,
          score: diagnosis.public_send(score_attribute),
          title: title_for(category, rank),
          badge_key: badge_key_for(category, rank)
        )
      end
    end

    def ranked_diagnoses_for(score_attribute)
      best_by_customer = {}

      base_scope(score_attribute).each do |diagnosis|
        best_by_customer[diagnosis.customer_id] ||= diagnosis
      end

      best_by_customer.values.sort_by do |diagnosis|
        [
          -diagnosis.public_send(score_attribute),
          diagnosis.created_at || Time.zone.at(0),
          diagnosis.id || 0
        ]
      end
    end

    def base_scope(score_attribute)
      SingingDiagnosis
        .completed
        .joins(:customer)
        .where(ranking_opt_in: true)
        .where.not(score_attribute => nil)
        .where.not(diagnosed_at: nil)
        .where(diagnosed_at: season_time_range)
        .order(score_attribute => :desc, created_at: :asc, id: :asc)
    end

    def season_time_range
      season.starts_on.beginning_of_day..season.ends_on.end_of_day
    end

    def title_for(category, rank)
      case category
      when "overall"
        return "今月のトップシンガー" if rank == 1
        return "月間TOP3" if rank <= 3
        return "月間TOP10" if rank <= 10
      when "pitch"
        return "Pitchリーダー" if rank == 1
        return "Pitch TOP3" if rank <= 3
      when "rhythm"
        return "Rhythmリーダー" if rank == 1
        return "Rhythm TOP3" if rank <= 3
      when "expression"
        return "Expressionリーダー" if rank == 1
        return "Expression TOP3" if rank <= 3
      end

      nil
    end

    def badge_key_for(category, rank)
      case category
      when "overall"
        return "monthly_overall_top_1" if rank == 1
        return "monthly_overall_top_3" if rank <= 3
        return "monthly_overall_top_10" if rank <= 10
      when "pitch"
        return "monthly_pitch_top_1" if rank == 1
        return "monthly_pitch_top_3" if rank <= 3
      when "rhythm"
        return "monthly_rhythm_top_1" if rank == 1
        return "monthly_rhythm_top_3" if rank <= 3
      when "expression"
        return "monthly_expression_top_1" if rank == 1
        return "monthly_expression_top_3" if rank <= 3
      end

      nil
    end
  end
end
