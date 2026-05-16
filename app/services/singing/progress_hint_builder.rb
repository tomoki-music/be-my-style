module Singing
  class ProgressHintBuilder
    ProgressHint = Struct.new(
      :badge_key,
      :progress_ratio,
      :hint_text,
      :detail_text,
      :current_value,
      :target_value,
      keyword_init: true
    )

    # hint 対象バッジ（MVP）
    HINT_BADGE_KEYS = %w[diagnosis_10 streak_7 streak_30 first_score_90 growth_10].freeze

    def self.call(customer, earned_badge_keys:)
      new(customer, earned_badge_keys: earned_badge_keys).call
    end

    def initialize(customer, earned_badge_keys:)
      @customer          = customer
      @earned_badge_keys = earned_badge_keys
    end

    def call
      HINT_BADGE_KEYS.filter_map do |badge_key|
        next if @earned_badge_keys.include?(badge_key)

        build_hint(badge_key)
      end
    end

    private

    # ─────────────────────────────────────────────────────────
    # hint builders per badge
    # ─────────────────────────────────────────────────────────

    def build_hint(badge_key)
      case badge_key
      when "diagnosis_10"   then diagnosis_10_hint
      when "streak_7"       then streak_hint(7)
      when "streak_30"      then streak_hint(30)
      when "first_score_90" then score_90_hint
      when "growth_10"      then growth_10_hint
      end
    end

    def diagnosis_10_hint
      current   = completed_count
      target    = 10
      ratio     = (current.to_f / target).clamp(0.0, 1.0)
      return nil if ratio >= 1.0

      remaining = target - current
      ProgressHint.new(
        badge_key:      "diagnosis_10",
        progress_ratio: ratio,
        hint_text:      "あと#{remaining}回で「10 Songs」",
        detail_text:    "累計#{current}回 / 目標#{target}回",
        current_value:  current,
        target_value:   target
      )
    end

    def streak_hint(days)
      current   = current_streak
      target    = days
      ratio     = (current.to_f / target).clamp(0.0, 1.0)
      return nil if ratio >= 1.0

      remaining = target - current
      label     = days == 7 ? "7 Day Streak" : "Monthly Devotee"
      ProgressHint.new(
        badge_key:      "streak_#{days}",
        progress_ratio: ratio,
        hint_text:      "あと#{remaining}日で「#{label}」",
        detail_text:    "#{current}日連続 / 目標#{target}日",
        current_value:  current,
        target_value:   target
      )
    end

    def score_90_hint
      current   = best_score
      target    = 90
      ratio     = (current.to_f / target).clamp(0.0, 1.0)
      return nil if ratio >= 1.0

      remaining = target - current
      ProgressHint.new(
        badge_key:      "first_score_90",
        progress_ratio: ratio,
        hint_text:      "あと#{remaining}点で「Score 90 Club」",
        detail_text:    "#{current}点 / 目標#{target}点",
        current_value:  current,
        target_value:   target
      )
    end

    def growth_10_hint
      first_score = first_diagnosis_score
      return nil unless first_score

      current_best = best_score
      delta        = [current_best - first_score, 0].max
      target       = 10
      ratio        = (delta.to_f / target).clamp(0.0, 1.0)
      return nil if ratio >= 1.0

      remaining = target - delta
      ProgressHint.new(
        badge_key:      "growth_10",
        progress_ratio: ratio,
        hint_text:      "あと#{remaining}点成長で「Rising Star」",
        detail_text:    "+#{delta}点成長 / 目標+#{target}点",
        current_value:  delta,
        target_value:   target
      )
    end

    # ─────────────────────────────────────────────────────────
    # helpers（memoized）
    # ─────────────────────────────────────────────────────────

    def completed_count
      @completed_count ||= @customer.singing_diagnoses.completed.count
    end

    def current_streak
      @current_streak ||= Singing::StreakCalculator.call(@customer)
    end

    def best_score
      @best_score ||= @customer.singing_diagnoses.completed.maximum(:overall_score).to_i
    end

    def first_diagnosis_score
      @first_diagnosis_score ||= @customer.singing_diagnoses
                                          .completed
                                          .order(:created_at)
                                          .first
                                          &.overall_score
    end
  end
end
