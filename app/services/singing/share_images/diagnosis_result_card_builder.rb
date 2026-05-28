module Singing
  module ShareImages
    class DiagnosisResultCardBuilder
      SCORE_ITEM_KEYS = %i[pitch_score rhythm_score expression_score].freeze

      Card = Struct.new(
        :overall_score,
        :overall_delta,
        :overall_delta_label,
        :best_growth_label,
        :best_growth_delta_label,
        :streak_days,
        :streak_label,
        :has_previous,
        :performance_type_label,
        :headline,
        :x_share_text,
        keyword_init: true
      )

      def self.call(diagnosis)
        new(diagnosis).call
      end

      def initialize(diagnosis)
        @diagnosis = diagnosis
        @customer  = diagnosis&.customer
      end

      def call
        return nil unless diagnosis.present? && diagnosis.completed?

        Card.new(
          overall_score:          diagnosis.overall_score.to_i,
          overall_delta:          overall_delta,
          overall_delta_label:    overall_delta_label,
          best_growth_label:      best_growth_label,
          best_growth_delta_label: best_growth_delta_label,
          streak_days:            streak_days,
          streak_label:           streak_label,
          has_previous:           previous_diagnosis.present?,
          performance_type_label: performance_type_label,
          headline:               headline,
          x_share_text:           x_share_text
        )
      end

      private

      attr_reader :diagnosis, :customer

      def previous_diagnosis
        @previous_diagnosis ||= diagnosis.previous_completed_diagnosis
      end

      def overall_delta
        @overall_delta ||= begin
          return nil unless previous_diagnosis.present?
          return nil if diagnosis.overall_score.blank? || previous_diagnosis.overall_score.blank?

          diagnosis.overall_score.to_i - previous_diagnosis.overall_score.to_i
        end
      end

      def overall_delta_label
        return nil if overall_delta.nil?
        return "±0" if overall_delta.zero?

        overall_delta.positive? ? "+#{overall_delta}" : overall_delta.to_s
      end

      def growth_items
        @growth_items ||= begin
          return [] unless previous_diagnosis.present?

          SCORE_ITEM_KEYS.filter_map do |key|
            current  = diagnosis.public_send(key)
            previous = previous_diagnosis.public_send(key)
            next unless current && previous

            delta = current.to_i - previous.to_i
            { key: key, label: score_label_for(key), delta: delta }
          end
        end
      end

      def best_growth_item
        @best_growth_item ||= growth_items
          .select { |item| item[:delta].positive? }
          .max_by { |item| item[:delta] }
      end

      def best_growth_label
        best_growth_item&.dig(:label)
      end

      def best_growth_delta_label
        delta = best_growth_item&.dig(:delta)
        return nil unless delta

        delta.positive? ? "+#{delta}" : delta.to_s
      end

      def streak_days
        @streak_days ||= customer.present? ? Singing::StreakCalculator.call(customer) : 0
      end

      def streak_label
        return nil if streak_days <= 0

        "#{streak_days}日連続診断中"
      end

      def performance_type_label
        case diagnosis.performance_type.to_s
        when "vocal"       then "ボーカル"
        when "instrumental" then "楽器演奏"
        when "band"        then "バンド"
        else "歌唱"
        end
      end

      def headline
        if previous_diagnosis.present? && overall_delta.to_i.positive?
          "前回より +#{overall_delta}点"
        elsif previous_diagnosis.present?
          "スコアを記録しました"
        else
          "初回診断結果"
        end
      end

      def x_share_text
        parts = ["歌唱診断スコア #{diagnosis.overall_score}点を記録しました🎤"]
        parts << "前回より#{overall_delta_label}点" if overall_delta.to_i != 0 && overall_delta_label.present?
        parts << "#{best_growth_label}が#{best_growth_delta_label}伸びました📈" if best_growth_label.present?
        parts << "🔥 #{streak_days}日連続診断中！" if streak_days >= 2
        parts << "#BeMyStyle #歌唱診断 #歌ってみた"
        parts.join
      end

      def score_label_for(key)
        case key
        when :pitch_score      then "音程"
        when :rhythm_score     then "リズム"
        when :expression_score then "表現力"
        else key.to_s
        end
      end
    end
  end
end
