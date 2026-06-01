module Singing
  class SessionRecommendationBuilder
    SessionRecommendation = Struct.new(
      :title,
      :message,
      :event_name,
      :event_url,
      :reason,
      :recommended_type,
      :cta_label,
      keyword_init: true
    )

    EVENTS = {
      beginner: {
        name: "初心者歓迎セッション",
        url: "/public/events"
      },
      acoustic: {
        name: "アコースティックセッション",
        url: "/public/events"
      },
      band: {
        name: "バンドセッション",
        url: "/public/events"
      },
      vocal: {
        name: "ボーカル向けセッション",
        url: "/public/events"
      },
      open: {
        name: "音楽コミュニティイベント",
        url: "/public/events"
      }
    }.freeze

    def self.call(customer, mission: nil, mission_matching: nil, growth_type: nil, recommended_journey: nil, mmm_connection: nil)
      new(
        customer,
        mission: mission,
        mission_matching: mission_matching,
        growth_type: growth_type,
        recommended_journey: recommended_journey,
        mmm_connection: mmm_connection
      ).call
    end

    def initialize(customer, mission: nil, mission_matching: nil, growth_type: nil, recommended_journey: nil, mmm_connection: nil)
      @customer = customer
      @mission = mission
      @mission_matching = mission_matching
      @growth_type = growth_type
      @recommended_journey = recommended_journey
      @mmm_connection = mmm_connection
    end

    def call
      event = EVENTS.fetch(recommended_type)

      SessionRecommendation.new(
        title: "今のあなたにおすすめ",
        message: message,
        event_name: event[:name],
        event_url: event[:url],
        reason: reason,
        recommended_type: recommended_type,
        cta_label: "イベントを見る"
      )
    end

    private

    def recommended_type
      @recommended_type ||= begin
        case mission_key
        when :expression
          :acoustic
        when :rhythm
          :band
        when :consistency
          :beginner
        when :voice
          :vocal
        else
          fallback_type
        end
      end
    end

    def fallback_type
      return :beginner if diagnosis_count < 3
      return :acoustic if growth_type_key == :emotional_singer
      return :band if growth_type_key == :rhythm_explorer

      :open
    end

    def message
      case recommended_type
      when :acoustic
        "表現力を伸ばしたいなら、実際に人前で歌う経験も大きな成長につながります。まずは温かい場で、声に気持ちを乗せてみよう。"
      when :band
        "リズムやグルーヴは、誰かと音を合わせることで体に入りやすくなります。バンドの空気に触れるだけでも、次の挑戦が見えてきます。"
      when :beginner
        "続けるきっかけを作りたい時期は、初心者歓迎の場がぴったりです。歌う場所を知るだけでも、次の一歩が軽くなります。"
      when :vocal
        "自分の声に向き合うなら、歌中心のイベントが合いそうです。短いフレーズでも、人に届く経験が声の自信になります。"
      else
        "歌う場所はたくさんあります。あなたに合うステージを、一緒に見つけていきましょう。"
      end
    end

    def reason
      case recommended_type
      when :acoustic
        "今日の挑戦が表現や感情に近いので、声のニュアンスを届けやすいセッションをおすすめします。"
      when :band
        "今日の挑戦がリズムやグルーヴに近いので、仲間と音を合わせる体験が成長につながりそうです。"
      when :beginner
        "今は無理なく続ける入口を作る時期です。見学や初参加しやすい場から始めるのが合っています。"
      when :vocal
        "今日の挑戦が声や音程に近いので、歌を中心に楽しめる場が今の成長に合いそうです。"
      else
        "今のデータでは絞り込みすぎず、音楽を楽しめる開かれた場から始めるのがおすすめです。"
      end
    end

    def mission_key
      @mission_matching&.mission_key || detect_mission_key
    end

    def detect_mission_key
      text = [@mission&.title, @mission&.description, @recommended_journey&.challenge&.challenge_type].compact.join(" ")

      if text.match?(/表現|感情|パフォーマンス|expression/)
        :expression
      elsif text.match?(/リズム|グルーヴ|テンポ|rhythm/)
        :rhythm
      elsif text.match?(/継続|習慣|初参加|1分|最初|一歩|streak|diagnosis_count/)
        :consistency
      elsif text.match?(/声|音域|発声|音程|フレーズ|pitch/)
        :voice
      else
        :general
      end
    end

    def growth_type_key
      @growth_type&.type_key&.to_sym
    end

    def diagnosis_count
      return 0 if @customer.nil?

      @diagnosis_count ||= @customer.singing_diagnoses.completed.count
    rescue NoMethodError
      0
    end
  end
end
