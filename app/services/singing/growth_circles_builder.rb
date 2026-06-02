module Singing
  class GrowthCirclesBuilder
    CHEER_THRESHOLD = 3
    CHEER_WINDOW_DAYS = 30

    GrowthCircle = Struct.new(
      :title,
      :description,
      :member_count,
      :message,
      :circle_type,
      keyword_init: true
    )

    GROWTH_TYPE_CIRCLES = {
      emotional_singer: {
        title:        "🎭 Emotional Singer Circle",
        description:  "感情表現を大切にする仲間たち",
        member_count: 23,
        message:      "歌で気持ちを伝えることを大切にしている仲間がいます。"
      },
      rhythm_explorer: {
        title:        "🥁 Rhythm Explorer Circle",
        description:  "リズムを楽しむ仲間たち",
        member_count: 18,
        message:      "リズムの奥深さを一緒に探求している仲間がいます。"
      },
      consistency_hero: {
        title:        "🔥 Consistency Circle",
        description:  "毎日コツコツ続ける仲間たち",
        member_count: 31,
        message:      "継続することの大切さを分かち合える仲間がいます。"
      },
      voice_challenger: {
        title:        "🎤 Voice Challenge Circle",
        description:  "音程に挑戦し続ける仲間たち",
        member_count: 15,
        message:      "正確さを追い求める仲間と、一緒に成長できます。"
      },
      dynamic_performer: {
        title:        "🌟 Dynamic Performer Circle",
        description:  "バランスよく磨く仲間たち",
        member_count: 12,
        message:      "全方位で成長することを楽しむ仲間がいます。"
      },
      groove_builder: {
        title:        "🎵 Groove Builder Circle",
        description:  "自分スタイルを探す仲間たち",
        member_count: 20,
        message:      "自分らしい歌を見つける旅を続けている仲間がいます。"
      }
    }.freeze

    MISSION_CIRCLES = {
      expression: {
        title:        "🎭 Expression Challenge Circle",
        description:  "表現力を磨く挑戦中の仲間たち",
        member_count: 14,
        message:      "感情の色を増やすことに挑戦している仲間がいます。"
      },
      rhythm: {
        title:        "🥁 Rhythm Practice Circle",
        description:  "リズムを練習している仲間たち",
        member_count: 12,
        message:      "リズムに乗る楽しさを広げている仲間がいます。"
      }
    }.freeze

    CHEER_CIRCLE_CONFIG = {
      title:        "✨ Cheer Circle",
      description:  "仲間を応援することを楽しむ輪",
      member_count: 27,
      message:      "応援することも、音楽コミュニティを育てる大切な力です。"
    }.freeze

    EMPTY_MESSAGE = "音楽を楽しむ仲間が集まっています。あなたらしい輪が見つかります。".freeze

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return [] if @customer.nil?

      circles = []
      circles << growth_type_circle
      circles += mission_circles
      circles << cheer_circle if cheer_active?
      circles.compact
    end

    private

    def growth_type_circle
      type_key = growth_type&.type_key
      return nil unless type_key

      config = GROWTH_TYPE_CIRCLES[type_key]
      return nil if config.nil?

      build_circle(config, circle_type: :"growth_type_#{type_key}")
    end

    def mission_circles
      config = MISSION_CIRCLES[mission_key]
      return [] if config.nil?

      [build_circle(config, circle_type: :"mission_#{mission_key}")]
    end

    def cheer_circle
      build_circle(CHEER_CIRCLE_CONFIG, circle_type: :cheer)
    end

    def cheer_active?
      recent_cheer_count >= CHEER_THRESHOLD
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      false
    end

    def recent_cheer_count
      @recent_cheer_count ||= @customer
        .singing_cheer_reactions
        .where(created_at: CHEER_WINDOW_DAYS.days.ago..Time.current)
        .count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def growth_type
      @growth_type ||= Singing::GrowthTypeAnalyzer.call(@customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def mission_key
      @mission_key ||= detect_mission_key
    end

    def detect_mission_key
      diagnoses = recent_diagnoses
      return nil if diagnoses.size < 2

      recent   = diagnoses[0]
      previous = diagnoses[1]

      deltas = {
        expression: score_delta(recent.expression_score, previous.expression_score),
        rhythm:     score_delta(recent.rhythm_score,     previous.rhythm_score)
      }
      key, value = deltas.max_by { |_, delta| delta }
      value.to_i.positive? ? key : nil
    rescue NoMethodError
      nil
    end

    def recent_diagnoses
      @recent_diagnoses ||= @customer
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
      return 0 unless current && previous

      current.to_i - previous.to_i
    end

    def build_circle(config, circle_type:)
      GrowthCircle.new(
        title:        config[:title],
        description:  config[:description],
        member_count: config[:member_count],
        message:      config[:message],
        circle_type:  circle_type
      )
    end
  end
end
