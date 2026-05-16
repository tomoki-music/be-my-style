module Singing
  class AwardAchievementBadgesService
    def self.call(diagnosis)
      new(diagnosis).call
    end

    def initialize(diagnosis)
      @diagnosis = diagnosis
      @customer  = diagnosis.customer
    end

    def call
      return unless diagnosis.completed?
      return unless customer.present?

      SingingAchievementBadge::MVP_BADGE_KEYS.each do |badge_key|
        next unless eligible?(badge_key)

        award!(badge_key)
      end
    end

    private

    attr_reader :diagnosis, :customer

    # ─────────────────────────────────────────────────────────
    # eligibility
    # ─────────────────────────────────────────────────────────

    def eligible?(badge_key)
      case badge_key
      when "first_diagnosis" then first_diagnosis?
      when "personal_best"   then personal_best?
      when "streak_7"        then streak_reached?(7)
      when "streak_30"       then streak_reached?(30)
      when "first_score_90"  then first_score_90?
      when "first_ranking"   then first_ranking?
      when "diagnosis_10"    then diagnosis_10?
      when "growth_10"       then growth_10?
      else false
      end
    end

    def first_diagnosis?
      past_completed_diagnoses.empty?
    end

    def personal_best?
      return false unless diagnosis.overall_score.present?

      previous_best = past_completed_diagnoses.maximum(:overall_score).to_i
      diagnosis.overall_score > previous_best
    end

    def streak_reached?(days)
      today = diagnosis.created_at.to_date
      streak_days(today) >= days
    end

    def first_score_90?
      return false unless diagnosis.overall_score.to_i >= 90

      past_completed_diagnoses.where("overall_score >= ?", 90).empty?
    end

    def first_ranking?
      return false unless diagnosis.ranking_opt_in?

      past_completed_diagnoses.where(ranking_opt_in: true).empty?
    end

    def diagnosis_10?
      completed_count == 10
    end

    def growth_10?
      return false unless diagnosis.overall_score.present?

      first = customer.singing_diagnoses.completed
                      .order(:created_at)
                      .first
      return false unless first && first.id != diagnosis.id
      return false unless first.overall_score.present?

      (diagnosis.overall_score - first.overall_score) >= 10
    end

    # ─────────────────────────────────────────────────────────
    # award
    # ─────────────────────────────────────────────────────────

    def award!(badge_key)
      SingingAchievementBadge.create!(
        customer:           customer,
        singing_diagnosis:  diagnosis,
        badge_key:          badge_key,
        earned_at:          diagnosis.created_at,
        metadata:           build_metadata(badge_key)
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      Rails.logger.info(
        "[AwardAchievementBadgesService] skip badge=#{badge_key} customer=#{customer.id} reason=#{e.class}"
      )
    end

    # ─────────────────────────────────────────────────────────
    # metadata snapshots
    # ─────────────────────────────────────────────────────────

    def build_metadata(badge_key)
      defn = SingingAchievementBadge::BADGE_DEFINITIONS[badge_key]
      base = {
        schema_version: 1,
        badge_key:      badge_key,
        badge_label:    defn[:label],
        earned_at_label: diagnosis.created_at.strftime("%Y年%-m月%-d日"),
        diagnosis_count: completed_count
      }

      extra = case badge_key
              when "personal_best"
                {
                  current_best_score:  diagnosis.overall_score,
                  previous_best_score: past_completed_diagnoses.maximum(:overall_score),
                  score_delta:         score_delta_for_personal_best,
                  overall_score:       diagnosis.overall_score,
                  pitch_score:         diagnosis.pitch_score,
                  rhythm_score:        diagnosis.rhythm_score,
                  expression_score:    diagnosis.expression_score
                }
              when "streak_7", "streak_30"
                days   = badge_key == "streak_7" ? 7 : 30
                today  = diagnosis.created_at.to_date
                start  = today - (days - 1).days
                {
                  streak_days:       days,
                  streak_start_date: start.to_s,
                  streak_end_date:   today.to_s
                }
              when "first_score_90"
                {
                  overall_score:    diagnosis.overall_score,
                  pitch_score:      diagnosis.pitch_score,
                  rhythm_score:     diagnosis.rhythm_score,
                  expression_score: diagnosis.expression_score
                }
              when "first_ranking"
                { ranking_opt_in: true }
              when "growth_10"
                first = customer.singing_diagnoses.completed.order(:created_at).first
                {
                  first_overall_score:   first&.overall_score,
                  current_overall_score: diagnosis.overall_score,
                  growth_delta:          diagnosis.overall_score.to_i - first&.overall_score.to_i,
                  first_diagnosed_at:    first&.created_at&.iso8601
                }
              else
                {}
              end

      base.merge(extra).compact
    end

    # ─────────────────────────────────────────────────────────
    # helpers (memoized)
    # ─────────────────────────────────────────────────────────

    def past_completed_diagnoses
      @past_completed_diagnoses ||= customer.singing_diagnoses
                                            .completed
                                            .where.not(id: diagnosis.id)
    end

    def completed_count
      @completed_count ||= customer.singing_diagnoses.completed.count
    end

    def streak_days(as_of_date)
      Singing::StreakCalculator.call(customer, as_of_date: as_of_date)
    end

    def score_delta_for_personal_best
      prev = past_completed_diagnoses.maximum(:overall_score)
      return nil unless prev && diagnosis.overall_score

      diagnosis.overall_score - prev
    end
  end
end
