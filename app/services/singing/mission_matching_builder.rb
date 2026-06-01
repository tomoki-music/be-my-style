module Singing
  class MissionMatchingBuilder
    MissionMatching = Struct.new(
      :title,
      :message,
      :growth_type_key,
      :mission_key,
      :matched_count,
      :cta_label,
      :cta_url,
      keyword_init: true
    )

    COMMUNITY_URL = "/public/communities/7".freeze

    BASE_COUNTS = {
      expression: 14,
      rhythm: 12,
      consistency: 18,
      voice: 10,
      general: 8
    }.freeze

    GROWTH_BONUS = {
      emotional_singer: 3,
      rhythm_explorer: 3,
      consistency_hero: 4,
      voice_challenger: 3,
      dynamic_performer: 2,
      groove_builder: 1
    }.freeze

    def self.call(customer, mission: nil, growth_type: nil, recommended_journey: nil, community_challenge: nil)
      new(
        customer,
        mission: mission,
        growth_type: growth_type,
        recommended_journey: recommended_journey,
        community_challenge: community_challenge
      ).call
    end

    def initialize(customer, mission: nil, growth_type: nil, recommended_journey: nil, community_challenge: nil)
      @customer = customer
      @mission = mission
      @growth_type = growth_type
      @recommended_journey = recommended_journey
      @community_challenge = community_challenge
    end

    def call
      MissionMatching.new(
        title: title,
        message: message,
        growth_type_key: growth_type_key,
        mission_key: mission_key,
        matched_count: matched_count,
        cta_label: "仲間を見てみる",
        cta_url: COMMUNITY_URL
      )
    end

    private

    def title
      case mission_key
      when :expression
        "感情表現を磨く仲間がいます"
      when :rhythm
        "リズムに乗る仲間がいます"
      when :consistency
        "今日も続ける仲間がいます"
      when :voice
        "声に向き合う仲間がいます"
      else
        "同じ方向へ挑戦している仲間がいます"
      end
    end

    def message
      case mission_key
      when :expression
        "今週、感情表現を磨こうとしている仲間がいます。あなただけではありません。一緒に、伝わる歌を育てていきましょう。"
      when :rhythm
        "今週、リズムやグルーヴを楽しみながら挑戦している仲間がいます。体で音を感じる一歩を、一緒に重ねていきましょう。"
      when :consistency
        "今週、短い時間でも歌う習慣を作ろうとしている仲間がいます。小さな継続は、ちゃんと音楽の力になります。"
      when :voice
        "今週、自分の声に向き合っている仲間がいます。声を探す時間は、あなたらしい歌に近づく大切な一歩です。"
      else
        "歌の成長に正解はありません。あなたらしい挑戦を見つけていく仲間がいます。焦らず、一緒に進んでいきましょう。"
      end
    end

    def mission_key
      @mission_key ||= begin
        text = [@mission&.title, @mission&.description, @recommended_journey&.challenge&.challenge_type].compact.join(" ")

        if text.match?(/表現|感情|パフォーマンス|expression/)
          :expression
        elsif text.match?(/リズム|グルーヴ|テンポ|rhythm/)
          :rhythm
        elsif text.match?(/継続|診断回数|習慣|1分|最初|一歩|streak|diagnosis_count/)
          :consistency
        elsif text.match?(/声|音域|発声|音程|フレーズ|pitch/)
          :voice
        else
          :general
        end
      end
    end

    def growth_type_key
      @growth_type_key ||= @growth_type&.type_key&.to_sym || :unknown
    end

    def matched_count
      community_count = @community_challenge&.participant_count.to_i
      base = BASE_COUNTS.fetch(mission_key, BASE_COUNTS[:general])
      bonus = GROWTH_BONUS.fetch(growth_type_key, 0)

      [base + bonus, community_count].max
    end
  end
end
