module Singing
  class MmmConnectionBuilder
    MmmConnection = Struct.new(
      :title,
      :message,
      :cta_label,
      :cta_url,
      :connection_type,
      keyword_init: true
    )

    EVENTS_URL = "/public/events".freeze
    COMMUNITY_URL = "/public/communities/7".freeze
    CUSTOMERS_URL = "/public/customers".freeze

    def self.call(customer, mission: nil, recommended_journey: nil, growth_type: nil)
      new(customer, mission: mission, recommended_journey: recommended_journey, growth_type: growth_type).call
    end

    def initialize(customer, mission: nil, recommended_journey: nil, growth_type: nil)
      @customer = customer
      @mission = mission
      @recommended_journey = recommended_journey
      @growth_type = growth_type
    end

    def call
      attrs =
        if beginner?
          beginner_connection
        elsif expression_mission?
          expression_event_connection
        elsif rhythm_mission?
          rhythm_community_connection
        elsif consistency_growth?
          consistency_connection
        elsif emotional_growth?
          emotional_connection
        elsif recommended_challenge?
          challenge_connection
        else
          fallback_connection
        end

      MmmConnection.new(attrs)
    end

    private

    def beginner?
      diagnosis_count < 3
    end

    def expression_mission?
      mission_title.match?(/感情|表現/)
    end

    def rhythm_mission?
      mission_title.match?(/リズム/)
    end

    def consistency_growth?
      growth_type&.type_key == :consistency_hero
    end

    def emotional_growth?
      growth_type&.type_key == :emotional_singer
    end

    def recommended_challenge?
      @recommended_journey&.challenge.present?
    end

    def beginner_connection
      {
        title: "音楽を楽しむ仲間がいます",
        message: "最初の一歩は、ひとりで抱えなくて大丈夫。MMMには初心者歓迎のイベントや、気軽に音楽を楽しむ仲間がいます。",
        cta_label: "イベントを見る",
        cta_url: EVENTS_URL,
        connection_type: :event
      }
    end

    def expression_event_connection
      {
        title: "表現力は人前で育つことがあります",
        message: "今日の挑戦で感じたことは、セッションや発表の場でも活きてきます。実際に誰かへ届ける経験が、歌の表情を深めてくれます。",
        cta_label: "イベントを見る",
        cta_url: EVENTS_URL,
        connection_type: :event
      }
    end

    def rhythm_community_connection
      {
        title: "リズムを楽しむ仲間とつながる",
        message: "リズムに乗る楽しさは、誰かと音を合わせるともっと広がります。MMMのコミュニティで、同じ音楽の空気に触れてみませんか。",
        cta_label: "コミュニティを見る",
        cta_url: COMMUNITY_URL,
        connection_type: :community
      }
    end

    def consistency_connection
      {
        title: "続けている仲間と交流する",
        message: "継続する力は、仲間の存在でさらに温かく続いていきます。同じように音楽を積み重ねている人を見つけてみませんか。",
        cta_label: "仲間を探す",
        cta_url: CUSTOMERS_URL,
        connection_type: :growth_type
      }
    end

    def emotional_connection
      {
        title: "感情表現を大切にする仲間がいます",
        message: "声に気持ちを乗せる楽しさは、MMMの仲間とも共有できます。あなたの表現を受け止めてくれる場所へ、少しだけ足を伸ばしてみよう。",
        cta_label: "仲間を探す",
        cta_url: CUSTOMERS_URL,
        connection_type: :growth_type
      }
    end

    def challenge_connection
      {
        title: "この挑戦は仲間とも広げられます",
        message: "今の挑戦を続けていく先に、同じ曲や同じテーマで音楽を楽しむ仲間との出会いがあります。",
        cta_label: "コミュニティを見る",
        cta_url: COMMUNITY_URL,
        connection_type: :challenge
      }
    end

    def fallback_connection
      {
        title: "音楽を楽しむ仲間がいます",
        message: "今日の小さな挑戦は、MMMの仲間やイベントにもつながっていきます。歌う時間を、少しずつ外の音楽体験へ広げていこう。",
        cta_label: "コミュニティを見る",
        cta_url: COMMUNITY_URL,
        connection_type: :community
      }
    end

    def mission_title
      @mission&.title.to_s
    end

    def growth_type
      @growth_type ||= Singing::GrowthTypeAnalyzer.call(@customer)
    rescue NameError, NoMethodError
      nil
    end

    def diagnosis_count
      return 0 if @customer.nil?

      @diagnosis_count ||= @customer.singing_diagnoses.completed.count
    rescue NoMethodError
      0
    end
  end
end
