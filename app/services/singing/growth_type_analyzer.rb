module Singing
  class GrowthTypeAnalyzer
    GROWTH_TYPES = {
      consistency_hero: {
        label:       "Consistency Hero",
        icon:        "🏆",
        description: "継続する力が武器。毎日の積み重ねが、圧倒的な成長につながっています。"
      },
      emotional_singer: {
        label:       "Emotional Singer",
        icon:        "✨",
        description: "感情表現の伸びが大きいタイプ。「伝わる歌」へ近づいています。"
      },
      voice_challenger: {
        label:       "Voice Challenger",
        icon:        "🎯",
        description: "音程への挑戦を続けるタイプ。正確さを追い求める姿勢が光ります。"
      },
      rhythm_explorer: {
        label:       "Rhythm Explorer",
        icon:        "🥁",
        description: "リズム感覚が際立つタイプ。グルーヴの世界を探索しています。"
      },
      dynamic_performer: {
        label:       "Dynamic Performer",
        icon:        "🌟",
        description: "バランスの取れた高いパフォーマンス。全方位で輝くステージ型。"
      },
      groove_builder: {
        label:       "Groove Builder",
        icon:        "🎵",
        description: "自分だけのグルーヴを育てる旅の始まり。これからの成長が楽しみです。"
      }
    }.freeze

    Result = Struct.new(:type_key, :label, :icon, :description, keyword_init: true)

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      diagnoses = fetch_diagnoses
      type_key  = determine_type(diagnoses)
      info      = GROWTH_TYPES[type_key]
      Result.new(type_key: type_key, label: info[:label], icon: info[:icon], description: info[:description])
    end

    private

    def fetch_diagnoses
      return [] if @customer.nil?

      @customer.singing_diagnoses
               .completed
               .where.not(overall_score: nil)
               .order(created_at: :desc, id: :desc)
               .to_a
    end

    def determine_type(diagnoses)
      return :groove_builder if diagnoses.empty?

      streak = Singing::StreakCalculator.call(@customer)
      return :consistency_hero if streak >= 7

      return :dynamic_performer if dynamic_performer?(diagnoses)
      return :rhythm_explorer   if rhythm_explorer?(diagnoses)
      return :emotional_singer  if emotional_singer?(diagnoses)
      return :voice_challenger  if voice_challenger?(diagnoses)

      :groove_builder
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

      valid = diagnoses.select { |d| d.rhythm_score && d.pitch_score && d.expression_score }
      return false if valid.empty?

      avg_rhythm     = valid.sum(&:rhythm_score).to_f / valid.size
      avg_pitch      = valid.sum(&:pitch_score).to_f / valid.size
      avg_expression = valid.sum(&:expression_score).to_f / valid.size

      avg_rhythm > avg_pitch && avg_rhythm > avg_expression
    end

    def emotional_singer?(diagnoses)
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

    def voice_challenger?(diagnoses)
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
  end
end
