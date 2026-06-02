module Singing
  class MusicSocialGraphBuilder
    ACTIVITY_WINDOW_DAYS = 30
    CANDIDATE_LIMIT      = 50

    MusicSocialGraph = Struct.new(
      :connected_members_count,
      :cheer_connections_count,
      :growth_type_connections_count,
      :mission_connections_count,
      :event_connections_count,
      :graph_message,
      keyword_init: true
    )

    def self.call(customer:)
      new(customer: customer).call
    end

    def initialize(customer:)
      @customer = customer
    end

    def call
      return empty_result if @customer.nil?

      cheer   = cheer_connection_ids
      growth  = growth_type_connection_ids
      mission = mission_connection_ids
      event   = event_connection_ids

      connected = (cheer | growth | mission | event).size

      MusicSocialGraph.new(
        connected_members_count:       connected,
        cheer_connections_count:       cheer.size,
        growth_type_connections_count: growth.size,
        mission_connections_count:     mission.size,
        event_connections_count:       event.size,
        graph_message:                 message_for(connected)
      )
    end

    private

    def cheer_connection_ids
      (cheered_ids + cheering_ids).uniq
    end

    def cheered_ids
      @cheered_ids ||= @customer.singing_cheer_reactions.pluck(:target_customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def cheering_ids
      @cheering_ids ||= @customer.received_singing_cheer_reactions.pluck(:customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def growth_type_connection_ids
      my_type = current_growth_type&.type_key
      return [] if my_type.blank?

      active_candidates
        .select { |c| growth_type_for(c)&.type_key == my_type }
        .map(&:id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def mission_connection_ids
      my_mission = current_mission_key
      return [] if my_mission == :unknown

      active_candidates
        .select { |c| mission_key_for(c) == my_mission }
        .map(&:id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def event_connection_ids
      my_join_part_ids = @customer.join_part_customers.pluck(:join_part_id)
      return [] if my_join_part_ids.empty?

      JoinPartCustomer
        .where(join_part_id: my_join_part_ids)
        .where.not(customer_id: @customer.id)
        .distinct
        .pluck(:customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def active_candidates
      @active_candidates ||= Customer
        .joins(:singing_diagnoses)
        .where.not(id: @customer.id)
        .where(singing_diagnoses: { status: :completed })
        .where(singing_diagnoses: { created_at: activity_window })
        .distinct
        .limit(CANDIDATE_LIMIT)
        .to_a
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def current_growth_type
      @current_growth_type ||= Singing::GrowthTypeAnalyzer.call(@customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def growth_type_for(customer)
      @growth_type_cache ||= {}
      @growth_type_cache[customer.id] ||= Singing::GrowthTypeAnalyzer.call(customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def current_mission_key
      @current_mission_key ||= mission_key_for(@customer)
    end

    def mission_key_for(customer)
      diagnoses = customer
        .singing_diagnoses
        .completed
        .where.not(overall_score: nil)
        .order(created_at: :desc, id: :desc)
        .limit(2)
        .to_a

      return :unknown if diagnoses.size < 2

      recent   = diagnoses[0]
      previous = diagnoses[1]
      deltas = {
        expression: score_delta(recent.expression_score, previous.expression_score),
        rhythm:     score_delta(recent.rhythm_score,     previous.rhythm_score)
      }
      key, value = deltas.max_by { |_, delta| delta }
      value.to_i.positive? ? key : :unknown
    rescue NoMethodError, ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      :unknown
    end

    def score_delta(current, previous)
      return 0 unless current && previous

      current.to_i - previous.to_i
    end

    def message_for(count)
      if count >= 20
        "音楽でつながる輪が広がっています🎵"
      elsif count >= 5
        "あなたの周りに音楽仲間の輪が生まれています🤝"
      else
        "これから少しずつ、音楽のつながりが育っていきます🌱"
      end
    end

    def empty_result
      MusicSocialGraph.new(
        connected_members_count:       0,
        cheer_connections_count:       0,
        growth_type_connections_count: 0,
        mission_connections_count:     0,
        event_connections_count:       0,
        graph_message:                 message_for(0)
      )
    end

    def activity_window
      ACTIVITY_WINDOW_DAYS.days.ago..Time.current
    end
  end
end
