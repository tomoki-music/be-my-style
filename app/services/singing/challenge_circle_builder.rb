module Singing
  class ChallengeCircleBuilder
    Challenge = Struct.new(
      :id,
      :title,
      :description,
      :icon,
      :start_date,
      :end_date,
      :target_value,
      :challenge_type,
      :participant_count,
      :completion_count,
      keyword_init: true
    ) do
      def completion_rate
        return 0 if participant_count.to_i.zero?

        [(completion_count.to_f / participant_count * 100).round, 100].min
      end

      def premium_only?
        challenge_type == :theme
      end
    end

    CHALLENGE_DEFINITIONS = [
      {
        id:             :streak_7,
        title:          "7日連続診断",
        description:    "7日間連続で歌声診断に挑戦しよう。継続する力が最大の武器です。",
        icon:           "🔥",
        target_value:   7,
        challenge_type: :streak
      },
      {
        id:             :diagnosis_5,
        title:          "今週5回診断",
        description:    "今週中に5回以上診断を完了させよう。数をこなすことで成長が見えてくる。",
        icon:           "🎤",
        target_value:   5,
        challenge_type: :diagnosis_count
      },
      {
        id:             :pitch_growth,
        title:          "音程 +3 成長",
        description:    "直近の診断と比べて音程スコアを3点以上伸ばそう。",
        icon:           "🎵",
        target_value:   3,
        challenge_type: :pitch_growth
      },
      {
        id:             :rhythm_growth,
        title:          "リズム +3 成長",
        description:    "直近の診断と比べてリズムスコアを3点以上伸ばそう。",
        icon:           "🥁",
        target_value:   3,
        challenge_type: :rhythm_growth
      },
      {
        id:             :expression_growth,
        title:          "表現力 +3 成長",
        description:    "直近の診断と比べて表現力スコアを3点以上伸ばそう。",
        icon:           "✨",
        target_value:   3,
        challenge_type: :expression_growth
      },
      {
        id:             :anison_month,
        title:          "アニソン月間チャレンジ",
        description:    "今月アニソンで3回以上診断しよう。曲名に「アニメ」「OP」「ED」「Theme」「主題歌」を含む曲で挑戦！",
        icon:           "🌟",
        target_value:   3,
        challenge_type: :theme
      }
    ].freeze

    def self.call
      new.call
    end

    def call
      now  = Time.current
      week = { start: now.beginning_of_week, end: now.end_of_week }
      month = { start: now.beginning_of_month, end: now.end_of_month }

      stats = build_community_stats

      CHALLENGE_DEFINITIONS.map do |defn|
        period = defn[:challenge_type] == :theme ? month : week
        Challenge.new(
          id:               defn[:id],
          title:            defn[:title],
          description:      defn[:description],
          icon:             defn[:icon],
          start_date:       period[:start],
          end_date:         period[:end],
          target_value:     defn[:target_value],
          challenge_type:   defn[:challenge_type],
          participant_count: stats[:participants][defn[:id]] || 0,
          completion_count:  stats[:completions][defn[:id]] || 0
        )
      end
    end

    private

    def build_community_stats
      {
        participants: compute_participants,
        completions:  compute_completions
      }
    end

    def compute_participants
      week_participants  = week_active_customer_ids
      month_participants = month_active_customer_ids

      CHALLENGE_DEFINITIONS.each_with_object({}) do |defn, h|
        h[defn[:id]] = defn[:challenge_type] == :theme ? month_participants : week_participants
      end
    end

    def compute_completions
      {
        streak_7:         streak_7_count,
        diagnosis_5:      diagnosis_5_count,
        pitch_growth:     score_growth_count(:pitch_score),
        rhythm_growth:    score_growth_count(:rhythm_score),
        expression_growth: score_growth_count(:expression_score),
        anison_month:     anison_count
      }
    end

    # ─── 個別集計 ──────────────────────────────────────────────────────

    def week_active_customer_ids
      @week_active ||= SingingDiagnosis
        .completed
        .where(created_at: week_range)
        .distinct
        .count(:customer_id)
    end

    def month_active_customer_ids
      @month_active ||= SingingDiagnosis
        .completed
        .where(created_at: month_range)
        .distinct
        .count(:customer_id)
    end

    def streak_7_count
      SingingDiagnosis
        .completed
        .where(created_at: 7.days.ago.beginning_of_day..Time.current)
        .group(:customer_id)
        .having("COUNT(DISTINCT DATE(created_at)) >= 7")
        .count
        .size
    end

    def diagnosis_5_count
      SingingDiagnosis
        .completed
        .where(created_at: week_range)
        .group(:customer_id)
        .having("COUNT(*) >= 5")
        .count
        .size
    end

    def score_growth_count(score_col)
      SingingDiagnosis
        .completed
        .where.not(score_col => nil)
        .where(created_at: 30.days.ago.beginning_of_day..Time.current)
        .group(:customer_id)
        .having("MAX(#{score_col}) - MIN(#{score_col}) >= 3")
        .count
        .size
    end

    def anison_count
      ANISON_KEYWORDS.reduce(
        SingingDiagnosis.completed.where(created_at: month_range).none
      ) { |scope, kw| scope.or(SingingDiagnosis.completed.where(created_at: month_range).where("song_title LIKE ?", "%#{kw}%")) }
        .group(:customer_id)
        .having("COUNT(*) >= 3")
        .count
        .size
    end

    ANISON_KEYWORDS = %w[アニメ OP ED Theme 主題歌 アニソン Anime].freeze

    def week_range
      now = Time.current
      now.beginning_of_week..now.end_of_week
    end

    def month_range
      now = Time.current
      now.beginning_of_month..now.end_of_month
    end
  end
end
