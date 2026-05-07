module Singing
  class NextBadgeService
    Hint = Struct.new(:key, :label, :description, keyword_init: true)

    MAX_HINTS = 3

    BADGE_EMOJI = {
      diagnoses_3:   "🎵",
      diagnoses_10:  "🎤",
      diagnoses_30:  "🎸",
      first_growth:  "📈",
      growth_plus_10: "⬆️",
      season_top_10: "🏅",
      season_top_1:  "🏆",
      overall_top_10: "⭐",
      overall_top_3:  "🌟"
    }.freeze

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return [] unless @customer

      candidates = []
      candidates.concat(diagnosis_candidates)
      candidates.concat(growth_candidates)
      candidates.concat(season_rank_candidates)
      candidates.concat(overall_rank_candidates)

      candidates
        .sort_by { |c| -c[:proximity_score] }
        .first(MAX_HINTS)
        .map { |c| Hint.new(key: c[:key], label: c[:label], description: c[:description]) }
    end

    private

    def diagnosis_count
      @diagnosis_count ||= SingingDiagnosis
        .completed
        .where(customer: @customer)
        .where.not(overall_score: nil)
        .count
    end

    def latest_growth_score
      @growth_score ||= begin
        scores = SingingDiagnosis
          .completed
          .where(customer: @customer)
          .where.not(overall_score: nil)
          .order(created_at: :desc, id: :desc)
          .limit(2)
          .pluck(:overall_score)
        scores.size >= 2 ? scores[0] - scores[1] : 0
      end
    end

    def current_season_rank
      @season_rank ||= Singing::RankingQuery.season_position_for(@customer.id)
    end

    def current_overall_rank
      @overall_rank ||= Singing::RankingQuery.position_for(@customer.id)
    end

    def badge_definition(key)
      RankingBadgeService::BADGE_DEFINITIONS[key]
    end

    def build_candidate(key, description, proximity_score)
      d = badge_definition(key)
      { key: key, label: d[:label], description: description, proximity_score: proximity_score }
    end

    def diagnosis_candidates
      count = diagnosis_count
      [
        [3,  :diagnoses_3],
        [10, :diagnoses_10],
        [30, :diagnoses_30]
      ].each do |threshold, key|
        next if count >= threshold
        remaining  = threshold - count
        proximity  = (count.to_f / threshold * 100).to_i
        return [build_candidate(key, "あと#{remaining}回の診断で獲得", proximity)]
      end
      []
    end

    def growth_candidates
      score = latest_growth_score
      return [] if score >= 10

      if score.positive?
        remaining = 10 - score
        proximity = (score.to_f / 10 * 100).to_i
        [build_candidate(:growth_plus_10, "あと#{remaining}点の成長幅で獲得", proximity)]
      elsif diagnosis_count >= 2
        [build_candidate(:first_growth, "前回より高いスコアを出して獲得", 5)]
      else
        []
      end
    end

    def season_rank_candidates
      rank = current_season_rank
      return [] unless rank

      candidates = []

      if rank > 10 && rank <= 20
        gap       = rank - 10
        proximity = ((21 - rank).to_f / 10 * 100).clamp(1, 99).to_i
        candidates << build_candidate(:season_top_10, "あと#{gap}順位でTOP10入り", proximity)
      end

      if rank >= 2 && rank <= 5
        gap       = rank - 1
        proximity = ((6 - rank).to_f / 5 * 100).clamp(1, 99).to_i
        candidates << build_candidate(:season_top_1, "あと#{gap}順位で今月の王者", proximity)
      end

      candidates
    end

    def overall_rank_candidates
      rank = current_overall_rank
      return [] unless rank

      candidates = []

      if rank > 10 && rank <= 25
        gap       = rank - 10
        proximity = ((26 - rank).to_f / 15 * 100).clamp(1, 99).to_i
        candidates << build_candidate(:overall_top_10, "あと#{gap}順位で総合TOP10", proximity)
      end

      if rank > 3 && rank <= 8
        gap       = rank - 3
        proximity = ((9 - rank).to_f / 5 * 100).clamp(1, 99).to_i
        candidates << build_candidate(:overall_top_3, "あと#{gap}順位で総合TOP3", proximity)
      end

      candidates
    end
  end
end
