module Singing
  class SuggestedMusiciansBuilder
    DEFAULT_LIMIT = 6
    MIN_LIMIT = 3
    CANDIDATE_LIMIT = 40
    WINDOW_DAYS = 90

    SuggestedMusicians = Struct.new(
      :musicians,
      keyword_init: true
    )

    MusicianCard = Struct.new(
      :customer,
      :reason,
      :profile_path,
      :reacted,
      keyword_init: true
    )

    ScoredMusician = Struct.new(
      :card,
      :score,
      keyword_init: true
    )

    GrowthType = Struct.new(
      :type_key,
      keyword_init: true
    )

    def self.call(customer, current_customer: nil, limit: DEFAULT_LIMIT)
      new(customer, current_customer: current_customer, limit: limit).call
    end

    def initialize(customer, current_customer: nil, limit: DEFAULT_LIMIT)
      @customer = customer
      @current_customer = current_customer
      @limit = normalized_limit(limit)
    end

    def call
      SuggestedMusicians.new(musicians: build_musicians)
    end

    private

    def build_musicians
      return [] if @customer.nil?

      cards = candidates
        .filter_map { |candidate| scored_musician_for(candidate) }
        .sort_by { |scored| [-scored.score, scored.card.customer.name.to_s, scored.card.customer.id] }
        .uniq { |scored| scored.card.customer.id }
        .first(@limit)
        .map(&:card)

      decorate_with_reacted(cards)
    end

    def candidates
      @candidates ||= Customer
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

    def scored_musician_for(candidate)
      matches = []
      score = 0

      if same_growth_type?(candidate)
        matches << :growth_type
        score += 3
      end

      if same_mission?(candidate)
        matches << :mission
        score += 2
      end

      if cheer_connected?(candidate)
        matches << :cheer
        score += 2
      end

      return nil if matches.empty?

      type = primary_reason_type(matches)
      ScoredMusician.new(
        score: score,
        card: MusicianCard.new(
          customer: candidate,
          reason: reason_for(type),
          profile_path: "/singing/users/#{candidate.id}",
          reacted: false
        )
      )
    end

    def decorate_with_reacted(cards)
      return cards.each { |card| card.reacted = false } if @current_customer.nil?

      target_ids = cards.map { |card| card.customer&.id }.compact.uniq
      return cards.each { |card| card.reacted = false } if target_ids.empty?

      reacted_ids = SingingProfileReaction
        .where(customer: @current_customer, reaction_type: "cheer", target_customer_id: target_ids)
        .pluck(:target_customer_id)
        .to_set

      cards.each { |card| card.reacted = reacted_ids.include?(card.customer&.id) }
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      cards.each { |card| card.reacted = false }
    end

    def same_growth_type?(candidate)
      current_growth_type&.type_key.present? &&
        growth_type_for(candidate)&.type_key == current_growth_type.type_key
    end

    def same_mission?(candidate)
      current_mission_key != :unknown && mission_key_for(candidate) == current_mission_key
    end

    def cheer_connected?(candidate)
      cheered_customer_ids.include?(candidate.id) || cheering_customer_ids.include?(candidate.id)
    end

    def primary_reason_type(matches)
      %i[growth_type mission cheer].find { |type| matches.include?(type) }
    end

    def reason_for(type)
      case type
      when :growth_type
        "同じGrowth Circleです"
      when :mission
        "同じテーマに挑戦しています"
      else
        "音楽のつながりがあります"
      end
    end

    def current_growth_type
      @current_growth_type ||= growth_type_for(@customer)
    end

    def growth_type_for(customer)
      return nil if customer.nil?

      @growth_type_by_customer_id ||= {}
      @growth_type_by_customer_id[customer.id] ||= GrowthType.new(type_key: growth_type_key_for(customer.id))
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
      @recent_diagnoses_by_customer_id[customer.id] ||= diagnoses_for(customer.id).first(2)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def diagnoses_for(customer_id)
      diagnoses_by_customer_id[customer_id.to_i] || []
    end

    def diagnoses_by_customer_id
      @diagnoses_by_customer_id ||= SingingDiagnosis
        .completed
        .where(customer_id: candidate_customer_ids)
        .where.not(overall_score: nil)
        .order(created_at: :desc, id: :desc)
        .to_a
        .group_by(&:customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      {}
    end

    def candidate_customer_ids
      @candidate_customer_ids ||= ([customer_id] + candidates.map(&:id)).compact.uniq
    end

    def customer_id
      @customer&.id
    end

    def growth_type_key_for(customer_id)
      diagnoses = diagnoses_for(customer_id)
      return :groove_builder if diagnoses.empty?
      return :consistency_hero if streak_for(customer_id) >= 7
      return :dynamic_performer if dynamic_performer?(diagnoses)
      return :rhythm_explorer if rhythm_explorer?(diagnoses)
      return :emotional_singer if emotional_singer?(diagnoses)
      return :voice_challenger if voice_challenger?(diagnoses)

      :groove_builder
    end

    def streak_for(customer_id)
      dates = diagnoses_for(customer_id)
        .select { |diagnosis| diagnosis.created_at <= Time.zone.today.end_of_day }
        .map { |diagnosis| diagnosis.created_at.to_date }
        .to_set

      count = 0
      date = Time.zone.today
      while dates.include?(date)
        count += 1
        date -= 1.day
      end
      count
    end

    def dynamic_performer?(diagnoses)
      recent = diagnoses.first
      return false if recent.overall_score.nil? || recent.overall_score < 70

      scores = [recent.pitch_score, recent.rhythm_score, recent.expression_score].compact
      return false if scores.size < 3

      (scores.max - scores.min) <= 10
    end

    def rhythm_explorer?(diagnoses)
      return false if diagnoses.size < 2

      valid = diagnoses.select { |diagnosis| diagnosis.rhythm_score && diagnosis.pitch_score && diagnosis.expression_score }
      return false if valid.empty?

      avg_rhythm = valid.sum(&:rhythm_score).to_f / valid.size
      avg_pitch = valid.sum(&:pitch_score).to_f / valid.size
      avg_expression = valid.sum(&:expression_score).to_f / valid.size

      avg_rhythm > avg_pitch && avg_rhythm > avg_expression
    end

    def emotional_singer?(diagnoses)
      return false if diagnoses.size < 2

      recent = diagnoses[0]
      previous = diagnoses[1]
      return false unless recent.expression_score && previous.expression_score

      expression_delta = recent.expression_score - previous.expression_score
      return false if expression_delta <= 0

      expression_delta > score_delta(recent.pitch_score, previous.pitch_score) &&
        expression_delta > score_delta(recent.rhythm_score, previous.rhythm_score)
    end

    def voice_challenger?(diagnoses)
      return false if diagnoses.size < 2

      recent = diagnoses[0]
      previous = diagnoses[1]
      return false unless recent.pitch_score && previous.pitch_score

      pitch_delta = recent.pitch_score - previous.pitch_score
      return false if pitch_delta <= 0

      pitch_delta >= score_delta(recent.expression_score, previous.expression_score) &&
        pitch_delta >= score_delta(recent.rhythm_score, previous.rhythm_score)
    end

    def score_delta(current, previous)
      return 0 if current.nil? || previous.nil?

      current.to_i - previous.to_i
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

    def normalized_limit(limit)
      value = limit.to_i
      value = DEFAULT_LIMIT unless value.positive?
      [[value, MIN_LIMIT].max, DEFAULT_LIMIT].min
    end

    def window_range
      WINDOW_DAYS.days.ago.beginning_of_day..Time.current
    end
  end
end
