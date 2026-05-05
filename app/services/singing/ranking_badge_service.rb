module Singing
  class RankingBadgeService
    Badge = Struct.new(:key, :label, :icon, :rarity, :premium_only, :animated, keyword_init: true) do
      def to_h
        {
          key: key,
          label: label,
          icon: icon,
          rarity: rarity,
          premium_only: premium_only,
          animated: animated
        }
      end
    end

    BADGE_DEFINITIONS = {
      first_diagnosis: {
        label: "初診断",
        icon: "♪",
        rarity: :common
      },
      diagnoses_3: {
        label: "3回診断達成",
        icon: "3",
        rarity: :common
      },
      diagnoses_10: {
        label: "10回診断達成",
        icon: "10",
        rarity: :rare
      },
      diagnoses_30: {
        label: "30回診断達成",
        icon: "30",
        rarity: :epic
      },
      first_growth: {
        label: "初成長",
        icon: "+",
        rarity: :common
      },
      growth_plus_10: {
        label: "成長幅 +10突破",
        icon: "↑",
        rarity: :rare
      },
      growth_top_3: {
        label: "成長TOP3",
        icon: "TOP",
        rarity: :epic
      },
      season_ranked: {
        label: "今月ランクイン",
        icon: "月",
        rarity: :common
      },
      season_top_10: {
        label: "今月TOP10",
        icon: "10",
        rarity: :rare
      },
      season_top_1: {
        label: "今月の王者",
        icon: "1",
        rarity: :legend
      },
      overall_top_10: {
        label: "総合TOP10",
        icon: "10",
        rarity: :rare
      },
      overall_top_3: {
        label: "総合TOP3",
        icon: "3",
        rarity: :epic
      }
    }.freeze

    BADGE_PRIORITY = [
      :season_top_1,
      :overall_top_3,
      :growth_top_3,
      :diagnoses_30,
      :season_top_10,
      :overall_top_10,
      :growth_plus_10,
      :diagnoses_10,
      :season_ranked,
      :first_growth,
      :diagnoses_3,
      :first_diagnosis
    ].freeze

    def self.badges_for(customer)
      return [] unless customer

      badges_for_bulk([customer])[customer.id] || []
    end

    def self.badges_for_bulk(customers)
      new(customers).badges_for_bulk
    end

    def initialize(customers)
      @customers = Array(customers).compact.uniq { |customer| customer.id }
      @customer_ids = @customers.map(&:id).compact
    end

    def badges_for_bulk
      return {} if customer_ids.empty?

      counts = diagnosis_counts
      growth = growth_scores
      growth_top3_ids = growth_top3_customer_ids
      season_ranks = season_rank_map
      overall_ranks = overall_rank_map

      customer_ids.each_with_object({}) do |customer_id, result|
        result[customer_id] = build_badges(
          diagnosis_count: counts[customer_id].to_i,
          growth_score: growth[customer_id].to_i,
          growth_top3: growth_top3_ids.include?(customer_id),
          season_rank: season_ranks[customer_id],
          overall_rank: overall_ranks[customer_id]
        )
      end
    end

    private

    attr_reader :customer_ids

    def build_badges(diagnosis_count:, growth_score:, growth_top3:, season_rank:, overall_rank:)
      keys = []

      keys << :first_diagnosis if diagnosis_count >= 1
      keys << :diagnoses_3 if diagnosis_count >= 3
      keys << :diagnoses_10 if diagnosis_count >= 10
      keys << :diagnoses_30 if diagnosis_count >= 30

      keys << :first_growth if growth_score.positive?
      keys << :growth_plus_10 if growth_score >= 10
      keys << :growth_top_3 if growth_top3

      keys << :season_ranked if season_rank.present?
      keys << :season_top_10 if season_rank.present? && season_rank <= 10
      keys << :season_top_1 if season_rank == 1

      keys << :overall_top_10 if overall_rank.present? && overall_rank <= 10
      keys << :overall_top_3 if overall_rank.present? && overall_rank <= 3

      keys.sort_by { |key| BADGE_PRIORITY.index(key) || BADGE_PRIORITY.length }
          .map { |key| badge_for(key) }
    end

    def badge_for(key)
      definition = BADGE_DEFINITIONS.fetch(key)
      Badge.new(
        key: key,
        label: definition.fetch(:label),
        icon: definition.fetch(:icon),
        rarity: definition.fetch(:rarity),
        premium_only: false,
        animated: false
      ).to_h
    end

    def diagnosis_counts
      SingingDiagnosis
        .completed
        .where(customer_id: customer_ids)
        .where.not(overall_score: nil)
        .group(:customer_id)
        .count
    end

    def growth_scores
      diagnoses = SingingDiagnosis
                    .completed
                    .where(customer_id: customer_ids)
                    .where.not(overall_score: nil)
                    .order(customer_id: :asc, created_at: :desc, id: :desc)
                    .group_by(&:customer_id)

      diagnoses.each_with_object({}) do |(customer_id, customer_diagnoses), result|
        latest = customer_diagnoses.first
        previous = customer_diagnoses.find do |diagnosis|
          diagnosis.created_at < latest.created_at ||
            (diagnosis.created_at == latest.created_at && diagnosis.id < latest.id)
        end

        result[customer_id] = previous ? latest.overall_score - previous.overall_score : 0
      end
    end

    def growth_top3_customer_ids
      Singing::RankingQuery.growth.first(3).map { |entry| entry.customer.id }
    end

    def season_rank_map
      ranked_customer_ids(
        SingingDiagnosis
          .completed
          .where(ranking_opt_in: true)
          .where.not(overall_score: nil)
          .where.not(diagnosed_at: nil)
          .where(diagnosed_at: Singing::RankingQuery.current_season_range)
          .order(overall_score: :desc, diagnosed_at: :desc, id: :desc)
          .pluck(:customer_id)
      )
    end

    def overall_rank_map
      ranked_customer_ids(
        SingingDiagnosis
          .completed
          .where(ranking_opt_in: true)
          .where.not(overall_score: nil)
          .order(overall_score: :desc, id: :desc)
          .pluck(:customer_id)
      )
    end

    def ranked_customer_ids(ordered_customer_ids)
      seen = {}
      rank = 0

      ordered_customer_ids.each_with_object({}) do |customer_id, result|
        next if seen[customer_id]

        seen[customer_id] = true
        rank += 1
        result[customer_id] = rank if customer_ids.include?(customer_id)
      end
    end
  end
end
