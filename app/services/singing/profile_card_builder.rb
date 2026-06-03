module Singing
  class ProfileCardBuilder
    STREAK_THRESHOLD = 7

    ACTIVITY_LABELS = {
      consistency_hero:  "コツコツ診断を重ねています",
      emotional_singer:  "挑戦を続けています",
      voice_challenger:  "挑戦を続けています",
      dynamic_performer: "挑戦を続けています",
      rhythm_explorer:   "リズムを楽しんでいます",
      groove_builder:    "最近歌を楽しんでいます"
    }.freeze

    DEFAULT_ACTIVITY_LABEL = "最近歌を楽しんでいます".freeze

    ProfileCard = Struct.new(
      :customer,
      :display_name,
      :avatar_attached,
      :growth_type_label,
      :growth_type_icon,
      :latest_activity_label,
      keyword_init: true
    )

    # ユーザー一覧用: 診断を一括取得してN+1を回避する
    def self.build_collection(users)
      return [] if users.blank?

      user_ids = users.map(&:id)
      diagnoses_by_user = SingingDiagnosis
        .completed
        .where.not(overall_score: nil)
        .where(customer_id: user_ids)
        .order(created_at: :desc, id: :desc)
        .group_by(&:customer_id)

      users.filter_map do |user|
        user_diagnoses = diagnoses_by_user[user.id] || []
        new(user, diagnoses: user_diagnoses).call
      end
    end

    def self.call(customer, diagnoses: nil)
      new(customer, diagnoses: diagnoses).call
    end

    def initialize(customer, diagnoses: nil)
      @customer  = customer
      @diagnoses = diagnoses
    end

    def call
      return nil if @customer.nil?

      gt = growth_type_result
      ProfileCard.new(
        customer:              @customer,
        display_name:          @customer.name.to_s,
        avatar_attached:       avatar_attached?,
        growth_type_label:     gt[:label],
        growth_type_icon:      gt[:icon],
        latest_activity_label: activity_label(gt[:type_key])
      )
    end

    private

    def diagnoses
      @diagnoses ||= fetch_diagnoses
    end

    def fetch_diagnoses
      @customer.singing_diagnoses
               .completed
               .where.not(overall_score: nil)
               .order(created_at: :desc, id: :desc)
               .to_a
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def avatar_attached?
      @customer.profile_image.attached?
    rescue StandardError
      false
    end

    def growth_type_result
      type_key = determine_type
      info = Singing::GrowthTypeAnalyzer::GROWTH_TYPES[type_key]
      { type_key: type_key, label: info[:label], icon: info[:icon] }
    end

    def determine_type
      return :groove_builder if diagnoses.empty?
      return :consistency_hero if streak_days >= STREAK_THRESHOLD
      return :dynamic_performer if dynamic_performer?
      return :rhythm_explorer   if rhythm_explorer?
      return :emotional_singer  if emotional_singer?
      return :voice_challenger  if voice_challenger?

      :groove_builder
    end

    # preloaded diagnoses からインメモリでストリークを計算する(StreakCalculatorのDB呼び出しを避ける)
    def streak_days
      @streak_days ||= begin
        dates = diagnoses.map { |d| d.created_at.to_date }.uniq.to_set
        count = 0
        date  = Date.current
        while dates.include?(date)
          count += 1
          date  -= 1.day
        end
        count
      end
    end

    def dynamic_performer?
      recent = diagnoses.first
      return false if recent&.overall_score.nil? || recent.overall_score < 70

      scores = [recent.pitch_score, recent.rhythm_score, recent.expression_score].compact
      return false if scores.size < 3

      (scores.max - scores.min) <= 10
    end

    def rhythm_explorer?
      return false if diagnoses.size < 2

      valid = diagnoses.select { |d| d.rhythm_score && d.pitch_score && d.expression_score }
      return false if valid.empty?

      avg_rhythm     = valid.sum(&:rhythm_score).to_f / valid.size
      avg_pitch      = valid.sum(&:pitch_score).to_f / valid.size
      avg_expression = valid.sum(&:expression_score).to_f / valid.size

      avg_rhythm > avg_pitch && avg_rhythm > avg_expression
    end

    def emotional_singer?
      return false if diagnoses.size < 2

      recent   = diagnoses[0]
      previous = diagnoses[1]
      return false unless recent.expression_score && previous.expression_score

      expression_delta = recent.expression_score - previous.expression_score
      return false if expression_delta <= 0

      pitch_delta  = score_delta(recent.pitch_score, previous.pitch_score)
      rhythm_delta = score_delta(recent.rhythm_score, previous.rhythm_score)

      expression_delta > pitch_delta && expression_delta > rhythm_delta
    end

    def voice_challenger?
      return false if diagnoses.size < 2

      recent   = diagnoses[0]
      previous = diagnoses[1]
      return false unless recent.pitch_score && previous.pitch_score

      pitch_delta = recent.pitch_score - previous.pitch_score
      return false if pitch_delta <= 0

      expression_delta = score_delta(recent.expression_score, previous.expression_score)
      rhythm_delta     = score_delta(recent.rhythm_score, previous.rhythm_score)

      pitch_delta >= expression_delta && pitch_delta >= rhythm_delta
    end

    def score_delta(current, previous)
      return 0 unless current && previous

      current - previous
    end

    def activity_label(type_key)
      ACTIVITY_LABELS[type_key] || DEFAULT_ACTIVITY_LABEL
    end
  end
end
