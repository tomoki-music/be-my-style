module Singing
  class YearlyGrowthShareImageBuilder
    HASHTAG = "#BeMyStyleSinging".freeze

    ShareImage = Struct.new(
      :report,
      :headline,
      :growth_delta_label,
      :growth_range_label,
      :best_updates_label,
      :challenge_label,
      :song_label,
      :annual_copy,
      :hashtag,
      :x_share_text,
      keyword_init: true
    ) do
      def present?
        report&.present?
      end
    end

    def self.call(customer, reference_time: Time.current)
      new(customer, reference_time: reference_time).call
    end

    def initialize(customer, reference_time: Time.current)
      @customer = customer
      @reference_time = reference_time
    end

    def call
      report = Singing::YearlyGrowthReport.call(customer, reference_time: reference_time)

      ShareImage.new(
        report: report,
        headline: headline_for(report),
        growth_delta_label: growth_delta_label(report),
        growth_range_label: growth_range_label(report),
        best_updates_label: "#{report.personal_best_updates_count}回",
        challenge_label: challenge_label(report),
        song_label: song_label(report),
        annual_copy: report.emotional_copy,
        hashtag: HASHTAG,
        x_share_text: x_share_text(report)
      )
    end

    private

    attr_reader :customer, :reference_time

    def headline_for(report)
      if report.top_growth&.delta.to_i.positive?
        "#{report.top_growth.label}が今年いちばん伸びた"
      elsif report.diagnosis_count.to_i.positive?
        "今年も自分の声と向き合った"
      else
        "今年の声の記録をはじめよう"
      end
    end

    def growth_delta_label(report)
      return "集計待ち" unless report.top_growth

      "#{signed_number(report.top_growth.delta)}点"
    end

    def growth_range_label(report)
      return "2回以上の診断で集計" unless report.top_growth

      "#{report.top_growth.first_value}点から#{report.top_growth.last_value}点"
    end

    def challenge_label(report)
      return "未挑戦" unless report.top_challenge

      "#{report.top_challenge.label} #{report.top_challenge.count}回"
    end

    def song_label(report)
      return "未入力" unless report.top_song

      "#{report.top_song.title} #{report.top_song.count}回"
    end

    def x_share_text(report)
      [
        "BeMyStyleで#{report.year}年の歌声成長レポートを作りました。",
        "今年は#{report.diagnosis_count}回、自分の声を診断。",
        report.top_growth ? "いちばん伸びたのは#{report.top_growth.label}（#{growth_delta_label(report)}）" : nil,
        HASHTAG
      ].compact.join("\n")
    end

    def signed_number(value)
      value.to_i.positive? ? "+#{value.to_i}" : value.to_i.to_s
    end
  end
end
