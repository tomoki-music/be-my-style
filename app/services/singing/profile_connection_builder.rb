module Singing
  class ProfileConnectionBuilder
    CTA_MESSAGES = {
      high:    "応援し合える仲間が増えています",
      mid:     "同じ音楽を楽しむ仲間がいます",
      low:     "一緒に挑戦する仲間を見つけよう"
    }.freeze

    HIGH_CONNECTION_THRESHOLD = 10
    MID_CONNECTION_THRESHOLD  = 1

    ProfileConnection = Struct.new(
      :circle_name,
      :circle_slug,
      :connection_count,
      :show_follow_cta,
      :show_circle_cta,
      :cta_message,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return nil if @customer.nil?

      ProfileConnection.new(
        circle_name:      primary_growth_circle&.title,
        circle_slug:      circle_slug,
        connection_count: connection_count,
        show_follow_cta:  true,
        show_circle_cta:  circle_slug.present?,
        cta_message:      cta_message
      )
    end

    private

    def circles
      @circles ||= Singing::GrowthCirclesBuilder.call(@customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def primary_growth_circle
      @primary_growth_circle ||= circles.find { |c| c.circle_type.to_s.start_with?("growth_type_") }
    end

    def circle_slug
      return nil unless primary_growth_circle

      primary_growth_circle.circle_type.to_s.sub(/\Agrowth_type_/, "")
    end

    def social_graph
      @social_graph ||= Singing::MusicSocialGraphBuilder.call(customer: @customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def connection_count
      social_graph&.connected_members_count.to_i
    end

    def cta_message
      if connection_count >= HIGH_CONNECTION_THRESHOLD
        CTA_MESSAGES[:high]
      elsif connection_count >= MID_CONNECTION_THRESHOLD
        CTA_MESSAGES[:mid]
      else
        CTA_MESSAGES[:low]
      end
    end
  end
end
