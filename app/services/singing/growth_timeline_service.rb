module Singing
  class GrowthTimelineService
    Event = Struct.new(:key, :occurred_at, :title, :description, :event_type, keyword_init: true) do
      def month_label
        return "" if occurred_at.blank?

        "#{occurred_at.month}月"
      end
    end

    TARGET_LABELS = {
      "pitch" => "音程",
      "rhythm" => "リズム",
      "expression" => "表現力",
      "habit" => "練習習慣"
    }.freeze

    SCORE_TARGETS = {
      pitch_score: "音程",
      rhythm_score: "リズム",
      expression_score: "表現力"
    }.freeze

    DEFAULT_LIMIT = 10

    def self.call(customer, limit: DEFAULT_LIMIT)
      new(customer, limit: limit).call
    end

    def initialize(customer, limit: DEFAULT_LIMIT)
      @customer = customer
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      return [] if customer.blank?

      (diagnosis_events + challenge_events)
        .compact
        .sort_by { |event| [event.occurred_at || Time.zone.at(0), event.key.to_s] }
        .reverse
        .first(limit)
    end

    private

    attr_reader :customer, :limit

    def diagnosis_events
      completed_diagnoses.each_with_index.flat_map do |diagnosis, index|
        previous = completed_diagnoses[index + 1]
        best_before = best_scores_before_index[index] || {}

        [
          diagnosis_completed_event(diagnosis),
          score_up_event(diagnosis, previous),
          specific_growth_event(diagnosis, previous),
          personal_best_event(diagnosis, best_before)
        ].compact
      end
    end

    def completed_diagnoses
      @completed_diagnoses ||= customer.singing_diagnoses
                                     .completed
                                     .order(created_at: :desc, id: :desc)
                                     .limit(30)
                                     .to_a
    end

    def best_scores_before_index
      @best_scores_before_index ||= begin
        best = {}
        completed_diagnoses.reverse.each_with_object({}) do |diagnosis, memo|
          original_index = completed_diagnoses.index(diagnosis)
          memo[original_index] = best.dup
          best[diagnosis.performance_type] = [
            best[diagnosis.performance_type],
            diagnosis.overall_score
          ].compact.max
        end
      end
    end

    def diagnosis_completed_event(diagnosis)
      Event.new(
        key: "diagnosis_completed_#{diagnosis.id}",
        occurred_at: timeline_time(diagnosis),
        title: "#{diagnosis.performance_type_label}診断完了",
        description: diagnosis.overall_score.present? ? "総合スコア #{diagnosis.overall_score}点を記録しました。" : "診断結果を記録しました。",
        event_type: :diagnosis_completed
      )
    end

    def score_up_event(diagnosis, previous)
      return nil unless previous.present? && diagnosis.performance_type == previous.performance_type

      delta = score_delta(diagnosis.overall_score, previous.overall_score)
      return nil unless delta&.positive?

      Event.new(
        key: "score_up_#{diagnosis.id}",
        occurred_at: timeline_time(diagnosis),
        title: "総合スコア +#{delta}点成長",
        description: "前回の#{diagnosis.performance_type_label}診断から伸びています。",
        event_type: :score_up
      )
    end

    def specific_growth_event(diagnosis, previous)
      return nil unless previous.present? && diagnosis.performance_type == previous.performance_type

      best_growth = SCORE_TARGETS.filter_map do |attribute, label|
        delta = score_delta(diagnosis.public_send(attribute), previous.public_send(attribute))
        [label, delta] if delta&.positive?
      end.max_by { |(_, delta)| delta }
      return nil if best_growth.blank?

      label, delta = best_growth
      Event.new(
        key: "specific_growth_#{diagnosis.id}_#{label}",
        occurred_at: timeline_time(diagnosis),
        title: "#{label}スコア +#{delta}点成長",
        description: "前回より#{label}の変化が見えました。",
        event_type: :specific_growth
      )
    end

    def personal_best_event(diagnosis, best_before)
      return nil if diagnosis.overall_score.blank?

      previous_best = best_before[diagnosis.performance_type]
      return nil if previous_best.blank? || diagnosis.overall_score <= previous_best

      Event.new(
        key: "personal_best_#{diagnosis.id}",
        occurred_at: timeline_time(diagnosis),
        title: "#{diagnosis.performance_type_label}自己ベスト更新",
        description: "これまでの最高スコア #{previous_best}点を超えました。",
        event_type: :personal_best
      )
    end

    def challenge_events
      challenge_progresses.flat_map do |progress|
        [
          challenge_started_event(progress),
          challenge_completed_event(progress),
          challenge_badge_event(progress)
        ].compact
      end
    end

    def challenge_progresses
      @challenge_progresses ||= customer.singing_ai_challenge_progresses
                                       .where("tried = ? OR completed = ? OR next_diagnosis_planned = ?", true, true, true)
                                       .order(updated_at: :desc, id: :desc)
                                       .limit(20)
                                       .to_a
    end

    def challenge_started_event(progress)
      return nil unless progress.tried? || progress.next_diagnosis_planned? || progress.completed?

      Event.new(
        key: "challenge_started_#{progress.id}",
        occurred_at: progress.created_at,
        title: "#{target_label(progress)}チャレンジ開始",
        description: "今月のAIチャレンジとして取り組み始めました。",
        event_type: :challenge_started
      )
    end

    def challenge_completed_event(progress)
      return nil unless progress.completed?

      Event.new(
        key: "challenge_completed_#{progress.id}",
        occurred_at: progress.completed_at || progress.updated_at,
        title: "#{target_label(progress)}チャレンジ完了",
        description: "チェックを完了しました。次の診断で変化を見ていきましょう。",
        event_type: :challenge_completed
      )
    end

    def challenge_badge_event(progress)
      return nil unless progress.completed?

      definition = Singing::ChallengeBadgeService::TARGET_BADGES[progress.target_key]
      return nil if definition.blank?

      Event.new(
        key: "challenge_badge_#{progress.id}",
        occurred_at: progress.completed_at || progress.updated_at,
        title: "#{definition[:label]}バッジ獲得",
        description: definition[:earned_description],
        event_type: :challenge_badge
      )
    end

    def target_label(progress)
      TARGET_LABELS.fetch(progress.target_key, "AI")
    end

    def score_delta(current_score, previous_score)
      return nil if current_score.blank? || previous_score.blank?

      current_score.to_i - previous_score.to_i
    end

    def timeline_time(diagnosis)
      diagnosis.diagnosed_at || diagnosis.created_at
    end
  end
end
