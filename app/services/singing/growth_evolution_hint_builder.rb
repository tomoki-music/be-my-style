module Singing
  class GrowthEvolutionHintBuilder
    EVOLUTION_HINTS = {
      groove_builder:    "リズムの感覚を磨けば、Rhythm Explorer に近づいています",
      rhythm_explorer:   "表現力を磨けば Emotional Singer へ近づけます",
      emotional_singer:  "このまま継続すると Dynamic Performer への道が開けます",
      voice_challenger:  "連続7日で Consistency Hero に近づけます",
      dynamic_performer: "高いパフォーマンスを維持すれば、次のステージが見えてきます",
      consistency_hero:  "継続の力で、すべての成長タイプを超えていけます"
    }.freeze

    Result = Struct.new(:hint, keyword_init: true)

    def self.call(type_key)
      new(type_key).call
    end

    def initialize(type_key)
      @type_key = type_key.to_sym
    end

    def call
      hint = EVOLUTION_HINTS[@type_key] || EVOLUTION_HINTS[:groove_builder]
      Result.new(hint: hint)
    end
  end
end
