module Singing
  class ShareTextBuilder
    HASHTAG = "#BeMyStyleSinging".freeze

    def self.yearly_growth_report(customer, reference_time: Time.current, report: nil)
      new(customer, reference_time: reference_time).yearly_growth_report(report: report)
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
