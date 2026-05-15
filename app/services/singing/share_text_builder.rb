module Singing
  class ShareTextBuilder
    HASHTAG = "#BeMyStyleSinging".freeze

    def self.yearly_growth_report(customer, reference_time: Time.current, report: nil)
      new(customer, reference_time: reference_time).yearly_growth_report(report: report)
    end

    def self.daily_challenge(customer, reference_time: Time.current, card: nil)
      new(customer, reference_time: reference_time).daily_challenge(card: card)
    end

    def self.ranking(customer, reference_time: Time.current, card: nil)
      new(customer, reference_time: reference_time).ranking(card: card)
    end

    def self.monthly_wrapped(customer, reference_time: Time.current, stats: nil)
      new(customer, reference_time: reference_time).monthly_wrapped(stats: stats)
    end

    def self.yearly_wrapped(customer, reference_time: Time.current, stats: nil)
      new(customer, reference_time: reference_time).yearly_wrapped(stats: stats)
    end

    def initialize(customer, reference_time: Time.current)
      @customer = customer
      @reference_time = reference_time
    end

    def yearly_growth_report(report: nil)
      return generic_text unless detailed_share_available?

      report ||= Singing::YearlyGrowthReport.call(customer, reference_time: reference_time)
      return generic_text unless report.present?

      [
        "#{report.year}年は診断#{report.diagnosis_count}回！",
        growth_sentence(report),
        "🎤 ",
        HASHTAG
      ].compact.join
    end

    def daily_challenge(card: nil)
      parts = [card&.completed_today ? "今日もDaily Challenge完了🎤" : "Daily Challengeに挑戦中🎤"]
      parts << "前回より +#{card.score_delta.to_i}点アップ📈" if card&.score_delta.to_i.positive?
      parts << "小さな一歩を積み重ねています。"
      parts << "#BeMyStyle #歌唱診断 #歌ってみた"
      parts.join
    end

    def ranking(card: nil)
      parts = ["Singing Rankingに挑戦しました🏆"]
      parts << "現在 #{card.rank_label}🏆" if card&.rank.present?
      parts << (card&.message.presence || "挑戦の成果がランキングに刻まれました")
      parts << "#BeMyStyle #歌唱診断 #歌ってみた"
      parts.join
    end

    def monthly_wrapped(stats: nil)
      return generic_text unless stats.present?

      label = stats.year.present? && stats.month.present? ? "#{stats.year}年#{stats.month}月" : "今月"
      parts = ["#{label}は#{stats.diagnosis_count}回歌いました🎤"]
      if stats.score_improvement.to_f.positive?
        parts << "前月比 +#{stats.score_improvement}点スコアアップ📈"
      end
      if stats.top_skill_label.present? && stats.top_skill_delta.to_f.positive?
        parts << "#{stats.top_skill_label}が最も伸びました"
      end
      parts << "#BeMyStyle #歌唱診断 #MonthlyWrapped"
      parts.join
    end

    def yearly_wrapped(stats: nil)
      return generic_text unless stats.present?

      parts = ["#{stats.year}年は#{stats.diagnosis_count}回、自分の声と向き合いました🎤"]
      if stats.score_growth.to_i.positive?
        parts << "年間 +#{stats.score_growth}点成長📈"
      end
      if stats.top_skill_label.present? && stats.top_skill_delta.to_i.positive?
        parts << "#{stats.top_skill_label}が最も伸びた年でした"
      end
      if stats.longest_challenge_streak.to_i >= 7
        parts << "Daily Challenge #{stats.longest_challenge_streak}日連続継続🔥"
      end
      parts << "#BeMyStyle #歌唱診断 #YearlyWrapped"
      parts.join
    end

    private

    attr_reader :customer, :reference_time

    def detailed_share_available?
      customer.has_feature?(:singing_yearly_growth_report)
    end

    def growth_sentence(report)
      return nil unless report.top_growth&.delta.to_i&.positive?

      "#{report.top_growth.label}が#{report.top_growth.delta.to_i}点成長しました"
    end

    def generic_text
      "BeMyStyleで歌声診断をしました🎤 #{HASHTAG}"
    end
  end
end
