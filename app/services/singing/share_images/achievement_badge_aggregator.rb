module Singing
  module ShareImages
    class AchievementBadgeAggregator
      Stats = Struct.new(
        :earned_badges,
        :newest_badge,
        :total_count,
        :has_badges,
        keyword_init: true
      )

      def self.call(customer)
        new(customer).call
      end

      def initialize(customer)
        @customer = customer
      end

      def call
        return nil unless customer.present?

        badges = customer.singing_achievement_badges.earned.limit(5).to_a

        Stats.new(
          earned_badges: badges,
          newest_badge:  badges.first,
          total_count:   customer.singing_achievement_badges.count,
          has_badges:    badges.any?
        )
      end

      private

      attr_reader :customer
    end
  end
end
