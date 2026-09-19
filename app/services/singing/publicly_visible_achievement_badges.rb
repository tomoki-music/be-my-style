module Singing
  # 公開プロフィール(singing/users#show)に表示してよい SingingAchievementBadge の
  # badge_key 集合を返す。
  #
  # SingingAchievementBadge レコード自体には「非公開診断を根拠に獲得したか」を示す
  # カラムが無く、AwardAchievementBadgesService の成立条件(診断回数・自己ベスト・
  # ストリーク等)は customer の全診断(非公開含む)を対象に判定されているため、
  # レコードの有無だけでは公開可否を判断できない。
  #
  # そのため、AwardAchievementBadgesService と同じ成立条件を「公開診断(ranking_opt_in:
  # true)だけの履歴」で再計算し、非公開診断が無くても成立するbadge_keyだけを返す。
  # 診断内容に依存しないbadge_key(recap関連等)はそのまま許可する。
  class PubliclyVisibleAchievementBadges
    DIAGNOSIS_DEPENDENT_BADGE_KEYS = %w[
      first_diagnosis personal_best streak_7 streak_30
      first_score_90 first_ranking diagnosis_10 growth_10
    ].freeze

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return Set.new if @customer.nil?

      (SingingAchievementBadge::MVP_BADGE_KEYS.to_set - DIAGNOSIS_DEPENDENT_BADGE_KEYS) |
        achievable_diagnosis_dependent_keys
    end

    private

    def achievable_diagnosis_dependent_keys
      earned      = Set.new
      history     = []
      dates_seen  = Set.new

      public_diagnoses.each do |diagnosis|
        dates_seen << diagnosis.created_at.to_date

        DIAGNOSIS_DEPENDENT_BADGE_KEYS.each do |badge_key|
          next if earned.include?(badge_key)
          next unless eligible?(badge_key, diagnosis, history, dates_seen)

          earned << badge_key
        end

        history << diagnosis
      end

      earned
    end

    def public_diagnoses
      @public_diagnoses ||= @customer.singing_diagnoses
                                      .publicly_visible
                                      .completed
                                      .order(:created_at, :id)
                                      .to_a
    end

    # AwardAchievementBadgesService#eligible? と同じ条件を、publicly_visible な
    # 診断だけの履歴(history: 直前までの診断, dates_seen: 直前までの診断日を含む日付集合)
    # で再判定する。
    def eligible?(badge_key, diagnosis, history, dates_seen)
      case badge_key
      when "first_diagnosis" then history.empty?
      when "personal_best"   then personal_best?(diagnosis, history)
      when "streak_7"        then streak_length(dates_seen, diagnosis.created_at.to_date) >= 7
      when "streak_30"       then streak_length(dates_seen, diagnosis.created_at.to_date) >= 30
      when "first_score_90"  then first_score_90?(diagnosis, history)
      when "first_ranking"   then history.empty?
      when "diagnosis_10"    then history.size + 1 == 10
      when "growth_10"       then growth_10?(diagnosis, history)
      else false
      end
    end

    def personal_best?(diagnosis, history)
      return false unless diagnosis.overall_score.present?

      previous_best = history.filter_map(&:overall_score).max.to_i
      diagnosis.overall_score > previous_best
    end

    def first_score_90?(diagnosis, history)
      return false unless diagnosis.overall_score.to_i >= 90

      history.none? { |d| d.overall_score.to_i >= 90 }
    end

    def growth_10?(diagnosis, history)
      return false unless diagnosis.overall_score.present?

      first = history.first
      return false unless first&.overall_score.present?

      (diagnosis.overall_score - first.overall_score) >= 10
    end

    # StreakCalculator と同じアルゴリズムを、既にロード済みの日付集合に対して行う
    # (診断ごとにDBへ再クエリしN+1になるのを避けるため)。
    def streak_length(dates_seen, as_of_date)
      count = 0
      date  = as_of_date
      while dates_seen.include?(date)
        count += 1
        date  -= 1.day
      end
      count
    end
  end
end
