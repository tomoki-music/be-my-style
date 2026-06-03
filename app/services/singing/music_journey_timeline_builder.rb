module Singing
  class MusicJourneyTimelineBuilder
    STREAK_MILESTONES = [7, 30].freeze

    TimelineItem = Struct.new(
      :type,
      :title,
      :description,
      :occurred_at,
      :icon,
      keyword_init: true
    )

    MusicJourneyTimeline = Struct.new(
      :timeline_items,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return empty_timeline if @customer.nil?

      diagnoses = fetch_diagnoses
      return empty_timeline if diagnoses.empty?

      items = []
      items << first_diagnosis_item(diagnoses)
      items += personal_best_items(diagnoses)
      items += streak_milestone_items(diagnoses)

      sorted = items.compact.sort_by(&:occurred_at).reverse

      MusicJourneyTimeline.new(timeline_items: sorted)
    end

    private

    def fetch_diagnoses
      @customer.singing_diagnoses
               .completed
               .where.not(overall_score: nil)
               .order(created_at: :asc, id: :asc)
               .to_a
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def empty_timeline
      MusicJourneyTimeline.new(timeline_items: [])
    end

    def first_diagnosis_item(diagnoses)
      first = diagnoses.first
      return nil if first.nil?

      TimelineItem.new(
        type:        :first_diagnosis,
        title:       "はじめて歌唱診断を実施",
        description: "#{first.overall_score}点でスタート",
        occurred_at: first.created_at.to_date,
        icon:        "🎤"
      )
    end

    def personal_best_items(diagnoses)
      return [] if diagnoses.size < 2

      current_best = diagnoses.first.overall_score
      items = []

      diagnoses.drop(1).each do |diagnosis|
        next unless diagnosis.overall_score > current_best

        current_best = diagnosis.overall_score
        items << TimelineItem.new(
          type:        :personal_best,
          title:       "自己ベスト更新",
          description: "#{diagnosis.overall_score}点",
          occurred_at: diagnosis.created_at.to_date,
          icon:        "⭐"
        )
      end

      items
    end

    def streak_milestone_items(diagnoses)
      dates = diagnoses.map { |d| d.created_at.to_date }.uniq.sort
      return [] if dates.size < 2

      items = []
      streak = 1
      achieved = Set.new

      dates.each_cons(2) do |prev, curr|
        if curr == prev + 1.day
          streak += 1
          STREAK_MILESTONES.each do |milestone|
            next if achieved.include?(milestone)
            next unless streak >= milestone

            achieved.add(milestone)
            items << TimelineItem.new(
              type:        :streak_milestone,
              title:       "#{milestone}日継続達成",
              description: "#{milestone}日間連続で診断を続けました",
              occurred_at: curr,
              icon:        "🔥"
            )
          end
        else
          streak = 1
        end
      end

      items
    end
  end
end
