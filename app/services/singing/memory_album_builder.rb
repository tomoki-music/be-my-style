module Singing
  class MemoryAlbumBuilder
    AlbumItem = Struct.new(
      :type,
      :occurred_at,
      :title,
      :subtitle,
      :summary,
      :badge,
      :detail_url,
      keyword_init: true
    )

    AlbumResult = Struct.new(
      :items,
      keyword_init: true
    )

    MAX_MONTHS = 24

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return AlbumResult.new(items: []) if @customer.nil?

      items = []
      items.concat(year_recap_items)
      items.concat(monthly_wrapped_items)
      items.concat(singer_story_items)

      sorted = items.sort_by { |i| [-(i.occurred_at.year), -(i.occurred_at.month), -(i.occurred_at.day)] }
      AlbumResult.new(items: sorted)
    end

    private

    def year_recap_items
      years_with_data.filter_map do |year|
        recap = Singing::YearRecapBuilder.call(@customer, year: year)
        next unless recap.has_recap

        summary_parts = ["診断#{recap.diagnosis_count}回"]
        summary_parts << "最長#{recap.max_streak}日連続" if recap.max_streak >= 2

        AlbumItem.new(
          type:        :year_recap,
          occurred_at: Date.new(year, 12, 31),
          title:       "#{year}年 Singing Wrapped",
          subtitle:    recap.growth_type&.label,
          summary:     summary_parts.join(" / "),
          badge:       recap.growth_type&.icon || "🏆",
          detail_url:  nil
        )
      end
    end

    def monthly_wrapped_items
      months_with_data.first(MAX_MONTHS).filter_map do |year, month|
        wrapped = Singing::MonthlyWrappedBuilder.call(@customer, year: year, month: month)
        next unless wrapped.has_wrapped

        summary_parts = []
        if wrapped.most_improved_label.present? && wrapped.most_improved_delta.to_i > 0
          summary_parts << "#{wrapped.most_improved_label} +#{wrapped.most_improved_delta}pt"
        end
        summary_parts << "診断#{wrapped.diagnosis_count}回"

        AlbumItem.new(
          type:        :monthly_wrapped,
          occurred_at: Date.new(year, month, 1),
          title:       "#{year}年#{month}月 Monthly Wrapped",
          subtitle:    wrapped.growth_type&.label,
          summary:     summary_parts.join(" / "),
          badge:       wrapped.growth_type&.icon || "📊",
          detail_url:  nil
        )
      end
    end

    def singer_story_items
      recap = Singing::JourneyRecapBuilder.call(@customer)
      return [] unless recap.has_story

      latest_diagnosis = @customer.singing_diagnoses.completed.order(created_at: :desc).first
      occurred_at = latest_diagnosis&.created_at&.to_date || Date.current

      [AlbumItem.new(
        type:        :singer_story,
        occurred_at: occurred_at,
        title:       "Singer Story",
        subtitle:    recap.most_improved_label,
        summary:     recap.growth_story,
        badge:       "🎤",
        detail_url:  nil
      )]
    end

    def years_with_data
      @customer.singing_diagnoses
               .completed
               .where.not(overall_score: nil)
               .pluck(:created_at)
               .map(&:year)
               .uniq
               .sort
               .reverse
    end

    def months_with_data
      @customer.singing_diagnoses
               .completed
               .where.not(overall_score: nil)
               .pluck(:created_at)
               .map { |t| [t.year, t.month] }
               .uniq
               .sort_by { |y, m| [-y, -m] }
    end
  end
end
