module Singing
  class NextBadgeService
    Hint = Struct.new(
      :key,
      :label,
      :description,
      :badge_type,
      :title,
      :message,
      :icon,
      :progress_label,
      :progress_percent,
      keyword_init: true
    )

    MAX_HINTS = 3
    CONSECUTIVE_ENTRY_TARGET = 3
    GROWTH_TOP_LIMIT = 5
    MAX_GROWTH_GAP = 10.0

    BADGE_EMOJI = {
      diagnoses_3:   "🎵",
      diagnoses_10:  "🎤",
      diagnoses_30:  "🎸",
      first_growth:  "📈",
      growth_plus_10: "⬆️",
      season_top_10: "🏅",
      season_top_1:  "🏆",
      overall_top_10: "⭐",
      overall_top_3:  "🌟",
      monthly_top_10: "🎯",
      monthly_top_3: "🥉",
      monthly_runner_up: "🥈",
      monthly_champion: "🥇",
      growth_singer: "📈",
      consecutive_entry: "🔥",
      season_participant: "🔥"
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
      candidates.concat(season_badge_candidates)
      candidates.concat(season_rank_candidates)
      candidates.concat(overall_rank_candidates)

      candidates
        .sort_by { |c| -c[:proximity_score] }
        .first(MAX_HINTS)
        .map { |c| build_hint(c) }
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
      @season_rank ||= current_season_entry&.rank || Singing::RankingQuery.season_position_for(@customer.id)
    end

    def current_overall_rank
      @overall_rank ||= Singing::RankingQuery.position_for(@customer.id)
    end

    def badge_definition(key)
      RankingBadgeService::BADGE_DEFINITIONS[key]
    end

    def badge_label_for(badge_type, fallback_key)
      SingingBadge::BADGE_LABELS[badge_type.to_s] || badge_definition(fallback_key)&.dig(:label) || badge_type.to_s
    end

    def badge_icon_for(key, badge_type)
      BADGE_EMOJI[key] || SingingBadge::BADGE_EMOJIS[badge_type.to_s] || "🎯"
    end

    def build_candidate(key, description, proximity_score, badge_type: key, title: nil, icon: nil,
                        progress_label: nil, progress_percent: nil)
      badge_type = badge_type.to_s
      title ||= badge_label_for(badge_type, key)
      {
        key: key,
        badge_type: badge_type,
        label: title,
        title: title,
        description: description,
        message: description,
        icon: icon || badge_icon_for(key, badge_type),
        progress_label: progress_label,
        progress_percent: progress_percent,
        proximity_score: proximity_score
      }
    end

    def build_hint(candidate)
      Hint.new(
        key: candidate[:key],
        label: candidate[:label],
        description: candidate[:description],
        badge_type: candidate[:badge_type],
        title: candidate[:title],
        message: candidate[:message],
        icon: candidate[:icon],
        progress_label: candidate[:progress_label],
        progress_percent: candidate[:progress_percent]
      )
    end

    def current_season
      @current_season ||= SingingRankingSeason
                          .current
                          .order(starts_on: :desc, id: :desc)
                          .first
    end

    def previous_season
      return nil unless current_season

      @previous_season ||= SingingRankingSeason
                           .where("starts_on < ?", current_season.starts_on)
                           .order(starts_on: :desc, id: :desc)
                           .first
    end

    def current_season_entry
      return nil unless current_season

      @current_season_entry ||= current_season
                                .singing_season_ranking_entries
                                .overall
                                .find_by(customer: @customer)
    end

    def previous_season_entry
      return nil unless previous_season

      @previous_season_entry ||= previous_season
                                 .singing_season_ranking_entries
                                 .overall
                                 .find_by(customer: @customer)
    end

    def participated_in_current_season?
      current_season_entry.present? || current_season_rank.present?
    end

    def earned_badge_type?(badge_type, season: nil)
      scope = @customer.singing_badges.where(badge_type: badge_type.to_s)
      scope = scope.where(singing_ranking_season: season) if season
      scope.exists?
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

    def season_badge_candidates
      candidates = []
      candidates << season_participant_candidate
      candidates << consecutive_entry_candidate
      candidates << growth_singer_candidate
      candidates.compact
    end

    def season_participant_candidate
      return nil unless current_season
      return nil if participated_in_current_season?
      return nil if earned_badge_type?(:season_participant, season: current_season)

      build_candidate(
        :season_participant,
        "今月の診断でシーズン参加バッジを狙えます！",
        20,
        badge_type: :season_participant,
        title: "シーズン参加まであと少し",
        progress_label: "0 / 1 シーズン",
        progress_percent: 0
      )
    end

    def consecutive_entry_candidate
      return nil if earned_badge_type?(:consecutive_entry)

      streak = current_consecutive_entry_count
      return nil unless streak.between?(1, CONSECUTIVE_ENTRY_TARGET - 1)

      remaining = CONSECUTIVE_ENTRY_TARGET - streak
      build_candidate(
        :consecutive_entry,
        "あと#{remaining}回参加で#{CONSECUTIVE_ENTRY_TARGET}シーズン連続参加！",
        (streak.to_f / CONSECUTIVE_ENTRY_TARGET * 100).to_i,
        badge_type: :consecutive_entry,
        title: "連続参加まであと少し",
        progress_label: "#{streak} / #{CONSECUTIVE_ENTRY_TARGET} シーズン",
        progress_percent: (streak.to_f / CONSECUTIVE_ENTRY_TARGET * 100).to_i
      )
    end

    def current_consecutive_entry_count
      return 0 unless current_season

      participated_season_ids = SingingSeasonRankingEntry
                                .overall
                                .where(customer: @customer)
                                .pluck(:singing_ranking_season_id)
                                .to_set

      SingingRankingSeason
        .where("starts_on <= ?", current_season.starts_on)
        .order(starts_on: :desc, id: :desc)
        .take_while { |season| participated_season_ids.include?(season.id) }
        .count
    end

    def growth_singer_candidate
      return nil unless current_season_entry && previous_season_entry
      return nil if earned_badge_type?(:growth_singer, season: current_season)

      growth_results = Singing::GrowthCalculator.call(current_season.id, limit: GROWTH_TOP_LIMIT)
      return nil if growth_results.size < GROWTH_TOP_LIMIT

      current_growth = current_season_entry.score - previous_season_entry.score
      border_growth = growth_results.last.growth_amount
      current_result = growth_results.find { |result| result.customer.id == @customer.id }

      if current_result
        build_candidate(
          :growth_singer,
          "現在、急成長TOP#{GROWTH_TOP_LIMIT}圏内です！このままシーズン終了を狙いましょう。",
          96,
          badge_type: :growth_singer,
          title: "急成長TOP#{GROWTH_TOP_LIMIT}圏内",
          progress_label: "+#{format_growth_amount(current_growth)}点",
          progress_percent: 100
        )
      else
        gap = border_growth - current_growth
        return nil unless gap.positive? && gap <= MAX_GROWTH_GAP

        build_candidate(
          :growth_singer,
          "急成長TOP#{GROWTH_TOP_LIMIT}まであと#{format_growth_amount(gap)}点！",
          ((1 - (gap / MAX_GROWTH_GAP)) * 100).clamp(1, 95).to_i,
          badge_type: :growth_singer,
          title: "急成長TOP#{GROWTH_TOP_LIMIT}まであと少し",
          progress_label: "あと#{format_growth_amount(gap)}点",
          progress_percent: ((1 - (gap / MAX_GROWTH_GAP)) * 100).clamp(1, 95).to_i
        )
      end
    end

    def season_rank_candidates
      rank = current_season_rank
      return [] unless rank

      candidates = []

      if rank <= 10
        candidates << build_candidate(
          :season_top_10,
          "現在TOP10圏内！このままシーズンTOP10を狙えます。",
          94,
          badge_type: :monthly_top_10,
          title: "TOP10圏内キープ中",
          progress_label: "#{rank}位 / TOP10",
          progress_percent: 100
        )
      elsif rank <= 15
        gap       = rank - 10
        proximity = ((16 - rank).to_f / 5 * 100).clamp(1, 99).to_i
        candidates << build_candidate(
          :season_top_10,
          "TOP10まであと#{gap}人！#{gap}順位アップでTOP10入り",
          proximity,
          badge_type: :monthly_top_10,
          title: "TOP10まであと少し",
          progress_label: "#{rank}位 / TOP10",
          progress_percent: proximity
        )
      end

      if rank <= 3
        candidates << build_candidate(
          :monthly_top_3,
          "現在TOP3圏内！上位称号を狙える位置です。",
          95,
          badge_type: :monthly_top_3,
          title: "TOP3圏内キープ中",
          progress_label: "#{rank}位 / TOP3",
          progress_percent: 100
        )
      elsif rank <= 6
        gap       = rank - 3
        proximity = ((7 - rank).to_f / 3 * 100).clamp(1, 99).to_i
        candidates << build_candidate(
          :monthly_top_3,
          "TOP3まであと#{gap}人！",
          proximity,
          badge_type: :monthly_top_3,
          title: "TOP3まであと少し",
          progress_label: "#{rank}位 / TOP3",
          progress_percent: proximity
        )
      end

      if rank.between?(2, 3)
        gap = rank - 1
        candidates << build_candidate(
          :season_top_1,
          "今月の王者まであと#{gap}人！",
          98,
          badge_type: :monthly_champion,
          title: "今月の王者まであと少し",
          progress_label: "#{rank}位 / 1位",
          progress_percent: rank == 2 ? 95 : 90
        )
      end

      if rank == 3
        candidates << build_candidate(
          :monthly_runner_up,
          "準優勝まであと1人！",
          93,
          badge_type: :monthly_runner_up,
          title: "準優勝まであと少し",
          progress_label: "3位 / 2位",
          progress_percent: 90
        )
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

    def format_growth_amount(value)
      format("%.1f", value.to_f)
    end
  end
end
