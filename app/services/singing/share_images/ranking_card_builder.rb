module Singing
  module ShareImages
    class RankingCardBuilder
      Card = Struct.new(
        :rank,
        :score,
        :rank_label,
        :score_label,
        :message,
        :badge_label,
        :rank_change,
        :rank_change_label,
        :best_diagnosis,
        :x_share_text,
        keyword_init: true
      )

      def self.call(customer, reference_time: Time.current)
        new(customer, reference_time: reference_time).call
      end

      def initialize(customer, reference_time: Time.current)
        @customer = customer
        @reference_time = reference_time
      end

      def call
        return nil unless customer.present?

        Card.new(
          rank: rank,
          score: score,
          rank_label: rank_label,
          score_label: score_label,
          message: message,
          badge_label: "Singing Ranking",
          rank_change: rank_change,
          rank_change_label: rank_change_label,
          best_diagnosis: best_diagnosis,
          x_share_text: x_share_text
        )
      end

      private

      attr_reader :customer, :reference_time

      def best_diagnosis
        @best_diagnosis ||= customer.singing_diagnoses
          .completed
          .where(ranking_opt_in: true)
          .where.not(overall_score: nil)
          .order(overall_score: :desc, id: :desc)
          .first
      end

      def rank
        @rank ||= best_diagnosis.present? ? Singing::RankingQuery.position_for(customer.id) : nil
      end

      def score
        @score ||= best_diagnosis&.overall_score
      end

      def rank_label
        return "全国#{rank}位" if rank.present?

        "ランキング参加前"
      end

      def score_label
        return "総合スコア #{score}点" if score.present?

        "次の診断でスコアを記録"
      end

      def message
        return "挑戦の成果がランキングに刻まれました" if rank.present?
        return "挑戦の記録を積み重ねています" if score.present?

        "次の挑戦でランキングに参加できます"
      end

      def rank_change
        @rank_change ||= begin
          entries = recent_overall_entries
          return nil if entries.size < 2

          entries.second.rank.to_i - entries.first.rank.to_i
        end
      end

      def rank_change_label
        return "順位推移は集計待ち" if rank_change.nil?
        return "前回と同じ順位" if rank_change.zero?
        return "前回より#{rank_change}位アップ" if rank_change.positive?

        "前回より#{rank_change.abs}位ダウン"
      end

      def recent_overall_entries
        @recent_overall_entries ||= SingingSeasonRankingEntry
          .overall
          .joins(:singing_ranking_season)
          .where(customer: customer)
          .where(singing_ranking_seasons: { status: %w[active closed] })
          .order("singing_ranking_seasons.ends_on DESC, singing_ranking_seasons.id DESC")
          .limit(2)
          .to_a
      end

      def x_share_text
        share_card = Card.new(rank: rank, rank_label: rank_label, message: message)
        Singing::ShareTextBuilder.ranking(customer, reference_time: reference_time, card: share_card)
      end
    end
  end
end
