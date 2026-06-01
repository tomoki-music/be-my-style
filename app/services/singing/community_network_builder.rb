module Singing
  class CommunityNetworkBuilder
    DEFAULT_LIMIT = 5
    CANDIDATE_LIMIT = 30
    WINDOW_DAYS = 90

    CommunityNetwork = Struct.new(
      :connections,
      :message,
      keyword_init: true
    )

    Connection = Struct.new(
      :customer_id,
      :display_name,
      :reason,
      :connection_type,
      :growth_type_label,
      :growth_type_icon,
      keyword_init: true
    )

    ScoredConnection = Struct.new(:connection, :score, keyword_init: true)

    def self.call(customer, limit: DEFAULT_LIMIT)
      new(customer, limit: limit).call
    end

    def initialize(customer, limit: DEFAULT_LIMIT)
      @customer = customer
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      connections = build_connections

      CommunityNetwork.new(
        connections: connections,
        message: message_for(connections)
      )
    end

    private

    def build_connections
      return [] if @customer.nil?

      candidates
        .filter_map { |candidate| scored_connection_for(candidate) }
        .sort_by { |scored| [-scored.score, scored.connection.display_name.to_s] }
        .first(@limit)
        .map(&:connection)
    end

    def candidates
      Customer
        .joins(:singing_diagnoses)
        .where.not(id: @customer.id)
        .where(singing_diagnoses: { status: :completed, created_at: window_range })
        .where.not(singing_diagnoses: { overall_score: nil })
        .distinct
        .includes(:singing_diagnoses)
        .limit(CANDIDATE_LIMIT)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def scored_connection_for(candidate)
      score = 0
      matches = []
      candidate_growth_type = growth_type_for(candidate)

      if same_growth_type?(candidate_growth_type)
        score += 3
        matches << :growth_type
      end

      if same_mission?(candidate)
        score += 2
        matches << :mission
      end

      if cheer_connected?(candidate)
        score += 2
        matches << :cheer
      end

      if similar_activity?(candidate)
        score += 1
        matches << :activity
      end

      return nil if score.zero?

      type = primary_connection_type(matches)
      ScoredConnection.new(
        score: score,
        connection: Connection.new(
          customer_id: candidate.id,
          display_name: candidate.name.presence || "Singing Member",
          reason: reason_for(type),
          connection_type: type,
          growth_type_label: candidate_growth_type&.label,
          growth_type_icon: candidate_growth_type&.icon
        )
      )
    end

    def same_growth_type?(candidate_growth_type)
      current_growth_type&.type_key.present? &&
        candidate_growth_type&.type_key == current_growth_type.type_key
    end

    def same_mission?(candidate)
      current_mission_key != :unknown && mission_key_for(candidate) == current_mission_key
    end

    def cheer_connected?(candidate)
      cheered_customer_ids.include?(candidate.id) || cheering_customer_ids.include?(candidate.id)
    end

    def similar_activity?(candidate)
      (diagnosis_count_for(candidate) - current_diagnosis_count).abs <= 2 ||
        (streak_for(candidate) - current_streak).abs <= 2
    end

    def primary_connection_type(matches)
      %i[growth_type mission cheer activity].find { |type| matches.include?(type) } || :activity
    end

    def reason_for(type)
      case type
      when :growth_type
        "同じ成長タイプです"
      when :mission
        "似た挑戦をしています"
      when :cheer
        "応援でつながっています"
      else
        "似たペースで活動しています"
      end
    end

    def message_for(connections)
      if connections.present?
        "あなたと近い仲間が見つかりました。歌う時間が、少しずつつながっています。"
      else
        "音楽を楽しむ仲間が増えています。これからつながりが広がっていきます。"
      end
    end

    def current_growth_type
      @current_growth_type ||= growth_type_for(@customer)
    end

    def growth_type_for(customer)
      return nil if customer.nil?

      @growth_type_by_customer_id ||= {}
      @growth_type_by_customer_id[customer.id] ||= Singing::GrowthTypeAnalyzer.call(customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def current_mission_key
      @current_mission_key ||= mission_key_for(@customer)
    end

    def mission_key_for(customer)
      diagnoses = recent_diagnoses_for(customer)
      return :unknown if diagnoses.empty?
      return :consistency if diagnoses.size < 2

      recent = diagnoses.first
      previous = diagnoses.second
      deltas = {
        expression: score_delta(recent.expression_score, previous.expression_score),
        rhythm: score_delta(recent.rhythm_score, previous.rhythm_score),
        voice: score_delta(recent.pitch_score, previous.pitch_score)
      }
      key, value = deltas.max_by { |_name, delta| delta }

      value.to_i.positive? ? key : :consistency
    rescue NoMethodError
      :unknown
    end

    def recent_diagnoses_for(customer)
      return [] if customer.nil?

      @recent_diagnoses_by_customer_id ||= {}
      @recent_diagnoses_by_customer_id[customer.id] ||= customer
        .singing_diagnoses
        .completed
        .where.not(overall_score: nil)
        .order(created_at: :desc, id: :desc)
        .limit(2)
        .to_a
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def score_delta(current, previous)
      return 0 if current.nil? || previous.nil?

      current.to_i - previous.to_i
    end

    def diagnosis_count_for(customer)
      return 0 if customer.nil?

      @diagnosis_count_by_customer_id ||= {}
      @diagnosis_count_by_customer_id[customer.id] ||= customer
        .singing_diagnoses
        .completed
        .where.not(overall_score: nil)
        .count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def current_diagnosis_count
      @current_diagnosis_count ||= diagnosis_count_for(@customer)
    end

    def streak_for(customer)
      return 0 if customer.nil?

      @streak_by_customer_id ||= {}
      @streak_by_customer_id[customer.id] ||= Singing::StreakCalculator.call(customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def current_streak
      @current_streak ||= streak_for(@customer)
    end

    def cheered_customer_ids
      @cheered_customer_ids ||= @customer.singing_cheer_reactions.pluck(:target_customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def cheering_customer_ids
      @cheering_customer_ids ||= @customer.received_singing_cheer_reactions.pluck(:customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def window_range
      WINDOW_DAYS.days.ago.beginning_of_day..Time.current
    end
  end
end
