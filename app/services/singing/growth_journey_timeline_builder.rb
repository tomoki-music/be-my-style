module Singing
  class GrowthJourneyTimelineBuilder
    TimelineItem = Struct.new(
      :type, :occurred_at, :icon, :title, :body, :highlight, :premium_detail,
      keyword_init: true
    ) do
      def date_label
        return "" if occurred_at.blank?

        "#{occurred_at.month}/#{occurred_at.day}"
      end
    end

    SCORE_THRESHOLDS   = [60, 70, 80].freeze
    STREAK_MILESTONES  = [3, 5, 10].freeze
    MAX_ITEMS          = 15
    NOTABLE_GROWTH_MIN = 7

    SCORE_ATTRIBUTES = {
      pitch_score:      "音程",
      rhythm_score:     "リズム",
      expression_score: "表現力"
    }.freeze

    TARGET_LABELS = {
      "pitch"      => "音程",
      "rhythm"     => "リズム",
      "expression" => "表現力",
      "habit"      => "練習習慣"
    }.freeze

    def self.call(customer, premium: false)
      new(customer, premium: premium).call
    end

    def initialize(customer, premium: false)
      @customer = customer
      @premium  = premium
    end

    def call
      return [] if customer.blank?

      [
        first_diagnosis_item,
        *score_milestone_items,
        *personal_best_items,
        *notable_growth_items,
        *streak_items,
        *mission_success_items,
        *ai_comment_items
      ].compact
        .sort_by { |item| item.occurred_at || Time.zone.at(0) }
        .first(MAX_ITEMS)
    end

    private

    attr_reader :customer, :premium

    def completed_diagnoses
      @completed_diagnoses ||= customer.singing_diagnoses
        .completed
        .order(created_at: :asc, id: :asc)
        .to_a
    end

    def first_diagnosis_item
      first = completed_diagnoses.first
      return nil if first.blank?

      score_text = first.overall_score.present? ? " / 総合スコア #{first.overall_score}点" : ""
      TimelineItem.new(
        type:           :first_diagnosis,
        occurred_at:    timeline_time(first),
        icon:           "🎤",
        title:          "初回診断を開始",
        body:           "#{first.performance_type_label}診断#{score_text}",
        highlight:      true,
        premium_detail: nil
      )
    end

    def score_milestone_items
      first_diag = completed_diagnoses.first
      SCORE_THRESHOLDS.filter_map do |threshold|
        crossing = completed_diagnoses.find { |d| d.overall_score.to_i >= threshold }
        next if crossing.blank? || crossing == first_diag

        TimelineItem.new(
          type:           :score_breakthrough,
          occurred_at:    timeline_time(crossing),
          icon:           threshold_icon(threshold),
          title:          "総合スコア#{threshold}点突破",
          body:           "#{crossing.performance_type_label}で#{crossing.overall_score}点を記録しました",
          highlight:      threshold >= 80,
          premium_detail: nil
        )
      end
    end

    def personal_best_items
      items       = []
      running_best = {}

      completed_diagnoses.each do |diagnosis|
        type  = diagnosis.performance_type
        score = diagnosis.overall_score
        next if score.blank?

        prev_best = running_best[type]
        if prev_best.nil?
          running_best[type] = score
        elsif score > prev_best
          items << TimelineItem.new(
            type:           :personal_best,
            occurred_at:    timeline_time(diagnosis),
            icon:           "⭐",
            title:          "#{diagnosis.performance_type_label}自己ベスト更新",
            body:           "#{prev_best}点 → #{score}点",
            highlight:      false,
            premium_detail: nil
          )
          running_best[type] = score
        end
      end

      items.last(3)
    end

    def notable_growth_items
      items = []

      completed_diagnoses.group_by(&:performance_type).each_value do |diagnoses|
        diagnoses.each_cons(2) do |prev, curr|
          best = SCORE_ATTRIBUTES.filter_map do |attr, label|
            delta = delta_value(curr.public_send(attr), prev.public_send(attr))
            [label, delta] if delta&.positive?
          end.max_by { |(_, d)| d }

          next if best.blank? || best[1] < NOTABLE_GROWTH_MIN

          label, delta = best
          items << TimelineItem.new(
            type:           :notable_growth,
            occurred_at:    timeline_time(curr),
            icon:           "📈",
            title:          "#{label} +#{delta}",
            body:           "#{label}スコアが大きく伸びました",
            highlight:      false,
            premium_detail: nil
          )
        end
      end

      items.last(3)
    end

    def streak_items
      dates = completed_diagnoses
        .filter_map { |d| (d.diagnosed_at || d.created_at)&.to_date }
        .uniq.sort

      return [] if dates.size < STREAK_MILESTONES.min

      items             = []
      current_streak    = 1
      emitted_milestones = []

      dates.each_cons(2) do |prev_date, curr_date|
        if (curr_date - prev_date).to_i == 1
          current_streak += 1
        else
          current_streak = 1
        end

        STREAK_MILESTONES.each do |milestone|
          next unless current_streak == milestone
          next if emitted_milestones.include?(milestone)

          milestone_diag = completed_diagnoses.find { |d|
            (d.diagnosed_at || d.created_at)&.to_date == curr_date
          }
          occurred = milestone_diag ? timeline_time(milestone_diag) : curr_date.to_time

          items << TimelineItem.new(
            type:           :streak,
            occurred_at:    occurred,
            icon:           "🔥",
            title:          "#{milestone}日連続診断達成",
            body:           milestone >= 5 ? "素晴らしい継続力です！" : "継続は力なり！",
            highlight:      milestone >= 5,
            premium_detail: nil
          )
          emitted_milestones << milestone
        end
      end

      items
    end

    def mission_success_items
      customer.singing_ai_challenge_progresses
        .where(completed: true)
        .order(updated_at: :asc)
        .limit(5)
        .filter_map do |progress|
          occurred = progress.completed_at || progress.updated_at
          next if occurred.blank?

          target = TARGET_LABELS.fetch(progress.target_key, "AI")
          TimelineItem.new(
            type:           :mission_success,
            occurred_at:    occurred,
            icon:           "🏆",
            title:          "#{target}チャレンジ成功",
            body:           "新しい課題に挑戦しました",
            highlight:      true,
            premium_detail: premium ? "AIチャレンジを達成し、次の診断で変化を確認しました" : nil
          )
        end
    end

    def ai_comment_items
      return [] unless premium

      completed_diagnoses
        .select { |d| d.ai_comment.present? }
        .last(3)
        .filter_map do |diagnosis|
          preview = diagnosis.ai_comment.to_s.slice(0, 55).strip
          next if preview.blank?

          ellipsis = diagnosis.ai_comment.to_s.length > 55 ? "…" : ""
          TimelineItem.new(
            type:           :ai_comment,
            occurred_at:    timeline_time(diagnosis),
            icon:           "🤖",
            title:          "AIコメントを受け取りました",
            body:           nil,
            highlight:      false,
            premium_detail: "「#{preview}#{ellipsis}」"
          )
        end
    end

    def threshold_icon(threshold)
      case threshold
      when 80 then "🎯"
      when 70 then "✨"
      else "📊"
      end
    end

    def timeline_time(diagnosis)
      diagnosis.diagnosed_at || diagnosis.created_at
    end

    def delta_value(a, b)
      return nil if a.blank? || b.blank?

      a.to_i - b.to_i
    end
  end
end
