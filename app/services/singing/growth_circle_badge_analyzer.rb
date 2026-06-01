module Singing
  class GrowthCircleBadgeAnalyzer
    GrowthCircleBadge = Struct.new(:key, :title, :description, :icon, :color, keyword_init: true)

    BADGE_DEFINITIONS = {
      community_supporter: {
        title:       "Community Supporter",
        description: "仲間を支える存在",
        icon:        "🤝",
        color:       "#4A90D9"
      },
      growth_inspirer: {
        title:       "Growth Inspirer",
        description: "挑戦が周囲を勇気づけている",
        icon:        "✨",
        color:       "#F5A623"
      },
      motivation_booster: {
        title:       "Motivation Booster",
        description: "周囲のやる気を引き出している",
        icon:        "🔥",
        color:       "#E74C3C"
      },
      consistency_champion: {
        title:       "Consistency Champion",
        description: "努力を積み重ねる達人",
        icon:        "⚡",
        color:       "#9B59B6"
      },
      rising_singer: {
        title:       "Rising Singer",
        description: "今もっとも伸びている挑戦者",
        icon:        "🚀",
        color:       "#2ECC71"
      }
    }.freeze

    # ─── 称号獲得の最低基準 ───────────────────────────────────────────
    THRESHOLDS = {
      community_supporter:  { sent_count:       3 },
      growth_inspirer:      { received_count:   3 },
      motivation_booster:   { distinct_cheered: 3 },
      consistency_champion: { streak_days:      7 },
      rising_singer:        { growth_delta:     3.0 }
    }.freeze

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    # 獲得したバッジをスコア降順で返す（primary は first）
    def call
      return [] if @customer.nil?

      BADGE_DEFINITIONS.keys.filter_map do |key|
        score = compute_score(key)
        next if score <= 0

        [key, score]
      end
      .sort_by { |_, score| -score }
      .map { |key, _| build_badge(key) }
    end

    private

    def build_badge(key)
      defn = BADGE_DEFINITIONS[key]
      GrowthCircleBadge.new(key: key, **defn)
    end

    def compute_score(key)
      case key
      when :community_supporter  then community_supporter_score
      when :growth_inspirer      then growth_inspirer_score
      when :motivation_booster   then motivation_booster_score
      when :consistency_champion then consistency_champion_score
      when :rising_singer        then rising_singer_score
      else 0
      end
    end

    # ─── 個別スコア計算 ──────────────────────────────────────────────

    def community_supporter_score
      threshold = THRESHOLDS[:community_supporter][:sent_count]
      return 0 if sent_count < threshold

      sent_count.to_f
    end

    def growth_inspirer_score
      threshold = THRESHOLDS[:growth_inspirer][:received_count]
      return 0 if received_count < threshold

      received_count.to_f
    end

    def motivation_booster_score
      threshold = THRESHOLDS[:motivation_booster][:distinct_cheered]
      return 0 if distinct_cheered_count < threshold

      # 多様な応援を重視
      distinct_cheered_count.to_f * 1.5
    end

    def consistency_champion_score
      threshold = THRESHOLDS[:consistency_champion][:streak_days]
      return 0 if streak_days < threshold

      streak_days.to_f * 2.0
    end

    def rising_singer_score
      threshold = THRESHOLDS[:rising_singer][:growth_delta]
      return 0 if recent_growth_delta < threshold

      recent_growth_delta * 3.0
    end

    # ─── データ取得（各1回のみ） ──────────────────────────────────────

    def sent_count
      @sent_count ||= @customer.singing_cheer_reactions.count
    end

    def received_count
      @received_count ||= @customer.received_singing_cheer_reactions.count
    end

    def distinct_cheered_count
      @distinct_cheered_count ||= @customer.singing_cheer_reactions
                                           .distinct
                                           .count(:target_customer_id)
    end

    def streak_days
      @streak_days ||= Singing::StreakCalculator.call(@customer)
    end

    def recent_growth_delta
      @recent_growth_delta ||= begin
        scores = @customer.singing_diagnoses
                          .completed
                          .where.not(overall_score: nil)
                          .order(created_at: :desc)
                          .limit(5)
                          .pluck(:overall_score)
        return 0.0 if scores.size < 2

        (scores.first - scores.last).to_f
      end
    end
  end
end
