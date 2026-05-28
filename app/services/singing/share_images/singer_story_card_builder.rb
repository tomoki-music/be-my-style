module Singing
  module ShareImages
    class SingerStoryCardBuilder
      Card = Struct.new(
        :year,
        :month,
        :period_label,
        :growth_type_label,
        :growth_type_icon,
        :singer_rank_label,
        :singer_rank_icon,
        :diagnosis_count,
        :active_days,
        :streak,
        :most_improved_label,
        :most_improved_delta,
        :wrapped_message,
        :coach_reflection,
        :has_premium_features,
        :has_data,
        :x_share_text,
        keyword_init: true
      )

      def self.call(customer, reference_time: Time.current)
        new(customer, reference_time: reference_time).call
      end

      def initialize(customer, reference_time: Time.current)
        @customer       = customer
        @reference_time = reference_time
      end

      def call
        return nil unless @customer.present?

        data = Singing::ShareImageBuilder.call(
          @customer,
          year:  @reference_time.year,
          month: @reference_time.month
        )
        return nil unless data.has_data

        Card.new(
          year:                 data.year,
          month:                data.month,
          period_label:         period_label(data),
          growth_type_label:    data.growth_type_label,
          growth_type_icon:     data.growth_type_icon,
          singer_rank_label:    data.singer_rank_label,
          singer_rank_icon:     data.singer_rank_icon,
          diagnosis_count:      data.diagnosis_count,
          active_days:          data.active_days,
          streak:               data.streak,
          most_improved_label:  data.most_improved_label,
          most_improved_delta:  data.most_improved_delta,
          wrapped_message:      data.wrapped_message,
          coach_reflection:     data.coach_reflection,
          has_premium_features: data.has_premium_features,
          has_data:             data.has_data,
          x_share_text:         build_x_share_text(data)
        )
      end

      private

      def period_label(data)
        "#{data.year}.#{data.month.to_s.rjust(2, '0')}"
      end

      def build_x_share_text(data)
        parts = []
        parts << "#{data.year}年#{data.month}月の歌の記録"
        parts << data.growth_type_label if data.growth_type_label.present?
        parts << "#{data.diagnosis_count}回 挑戦しました" if data.diagnosis_count.to_i > 0
        if data.most_improved_delta.to_i > 0 && data.most_improved_label.present?
          parts << "+#{data.most_improved_delta} #{data.most_improved_label}"
        end
        parts << "#BeMyStyle #歌の成長"
        parts.join(" ✨ ")
      end
    end
  end
end
