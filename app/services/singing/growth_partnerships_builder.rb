module Singing
  class GrowthPartnershipsBuilder
    MAX_PARTNERS = 3
    CANDIDATE_LIMIT = 50
    ACTIVITY_WINDOW_DAYS = 30
    ACTIVITY_PACE_TOLERANCE = 2

    GROWTH_TYPE_SCORE = 40
    MISSION_SCORE     = 30
    ACTIVITY_SCORE    = 20
    CHEER_SCORE       = 10

    GrowthPartnership = Struct.new(
      :customer,
      :display_name,
      :avatar_url,
      :partnership_reason,
      :growth_type,
      :mission_type,
      :activity_label,
      :compatibility_score,
      keyword_init: true
    )

    GrowthPartnershipsResult = Struct.new(
      :partners,
      :message,
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

      partners = build_partners

      GrowthPartnershipsResult.new(
        partners: partners,
        message: message_for(partners)
      )
    end

    private

    def build_partners
      candidates
        .filter_map { |candidate| build_partnership(candidate) }
        .sort_by { |p| -p.compatibility_score }
        .first(MAX_PARTNERS)
    end

    def candidates
      Customer
        .joins(:singing_diagnoses)
        .where.not(id: @customer.id)
        .where(singing_diagnoses: { status: :completed })
        .where(singing_diagnoses: { created_at: activity_window })
        .distinct
        .limit(CANDIDATE_LIMIT)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def build_partnership(candidate)
      score   = 0
      reasons = []

      candidate_growth_type = growth_type_for(candidate)

      if same_growth_type?(candidate_growth_type)
        score += GROWTH_TYPE_SCORE
        reasons << :growth_type
      end

      if same_mission?(candidate)
        score += MISSION_SCORE
        reasons << :mission
      end

      if similar_activity_pace?(candidate)
        score += ACTIVITY_SCORE
        reasons << :activity_pace
      end

      if cheer_connected?(candidate)
        score += CHEER_SCORE
        reasons << :cheer
      end

      return nil if score.zero?

      GrowthPartnership.new(
        customer:            candidate,
        display_name:        candidate.name.presence || "Singing Member",
        avatar_url:          nil,
        partnership_reason:  reason_for(reasons.first),
        growth_type:         growth_type_display(candidate_growth_type),
        mission_type:        mission_label_for(mission_key_for(candidate)),
        activity_label:      activity_label_for(candidate),
        compatibility_score: score
      )
    end

    def same_growth_type?(candidate_growth_type)
      current_growth_type&.type_key.present? &&
        candidate_growth_type&.type_key == current_growth_type.type_key
    end

    def same_mission?(candidate)
      mk = current_mission_key
      mk != :unknown && mission_key_for(candidate) == mk
    end

    def similar_activity_pace?(candidate)
      my_count    = current_recent_count
      their_count = recent_diagnosis_count_for(candidate)
      my_count.positive? && their_count.positive? &&
        (their_count - my_count).abs <= ACTIVITY_PACE_TOLERANCE
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      false
    end

    def cheer_connected?(candidate)
      cheered_customer_ids.include?(candidate.id) || cheering_customer_ids.include?(candidate.id)
    end

    def current_growth_type
      @current_growth_type ||= growth_type_for(@customer)
    end

    def growth_type_for(customer)
      return nil if customer.nil?

      @growth_type_cache ||= {}
      @growth_type_cache[customer.id] ||= Singing::GrowthTypeAnalyzer.call(customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def growth_type_display(growth_type_result)
      return nil unless growth_type_result

      "#{growth_type_result.icon} #{growth_type_result.label}"
    end

    def current_mission_key
      @current_mission_key ||= mission_key_for(@customer)
    end

    def mission_key_for(customer)
      diagnoses = recent_diagnoses_for(customer)
      return :unknown if diagnoses.size < 2

      recent   = diagnoses[0]
      previous = diagnoses[1]
      deltas = {
        expression: score_delta(recent.expression_score, previous.expression_score),
        rhythm:     score_delta(recent.rhythm_score,     previous.rhythm_score)
      }
      key, value = deltas.max_by { |_, delta| delta }
      value.to_i.positive? ? key : :unknown
    rescue NoMethodError
      :unknown
    end

    def recent_diagnoses_for(customer)
      return [] if customer.nil?

      @recent_diagnoses_cache ||= {}
      @recent_diagnoses_cache[customer.id] ||= customer
        .singing_diagnoses
        .completed
        .where.not(overall_score: nil)
        .order(created_at: :desc, id: :desc)
        .limit(2)
        .to_a
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def recent_diagnosis_count_for(customer)
      return 0 if customer.nil?

      @recent_count_cache ||= {}
      @recent_count_cache[customer.id] ||= customer
        .singing_diagnoses
        .completed
        .where(created_at: activity_window)
        .count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def current_recent_count
      @current_recent_count ||= recent_diagnosis_count_for(@customer)
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

    def reason_for(reason_key)
      case reason_key
      when :growth_type   then "同じ成長タイプの仲間です"
      when :mission       then "今の挑戦テーマが近い仲間です"
      when :activity_pace then "無理なく一緒に続けやすい仲間です"
      when :cheer         then "応援でつながっている仲間です"
      else                     "一緒に成長できる仲間です"
      end
    end

    def mission_label_for(mission_key)
      case mission_key
      when :expression then "Expression Practice"
      when :rhythm     then "Rhythm Practice"
      end
    end

    def activity_label_for(candidate)
      count = recent_diagnosis_count_for(candidate)
      if count >= 4
        "今週も活動中"
      elsif count >= 2
        "マイペースに継続中"
      else
        "ゆっくり成長中"
      end
    end

    def score_delta(current, previous)
      return 0 unless current && previous

      current.to_i - previous.to_i
    end

    def message_for(partners)
      if partners.any?
        "一緒に成長できそうな仲間が見つかりました🎵"
      else
        "もう少し活動が増えると、成長仲間が見つかります🌱"
      end
    end

    def empty_result
      GrowthPartnershipsResult.new(
        partners: [],
        message:  "もう少し活動が増えると、成長仲間が見つかります🌱"
      )
    end

    def activity_window
      ACTIVITY_WINDOW_DAYS.days.ago..Time.current
    end
  end
end
