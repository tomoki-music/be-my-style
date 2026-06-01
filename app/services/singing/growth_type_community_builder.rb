module Singing
  class GrowthTypeCommunityBuilder
    GrowthTypeCommunity = Struct.new(
      :growth_type_key,
      :title,
      :description,
      :community_message,
      :member_count,
      :cta_label,
      :cta_url,
      keyword_init: true
    )

    COMMUNITY_URL = "/public/communities/7".freeze

    COPY_BY_TYPE = {
      consistency_hero: {
        title: "コツコツ継続する仲間がいます",
        description: "Consistency Hero",
        community_message: "小さな積み重ねを大切にしている仲間がいます。続けるリズムは、ひとりより仲間と一緒の方が温かく育ちます。",
        member_count: 24
      },
      dynamic_performer: {
        title: "パフォーマンスを磨く仲間がいます",
        description: "Dynamic Performer",
        community_message: "表現力やステージ感を楽しみながら伸ばしている仲間がいます。歌う場が増えるほど、あなたらしさも広がります。",
        member_count: 16
      },
      rhythm_explorer: {
        title: "リズムを楽しむ仲間がいます",
        description: "Rhythm Explorer",
        community_message: "リズムに乗る楽しさを大切にしながら成長している仲間がいます。音に合わせる感覚は、誰かと一緒だともっと育ちます。",
        member_count: 21
      },
      emotional_singer: {
        title: "感情表現を大切にする仲間がいます",
        description: "Emotional Singer",
        community_message: "声に気持ちを乗せることを大切にしている仲間がいます。あなたの表現も、誰かの心に届く音楽の一部です。",
        member_count: 19
      },
      voice_challenger: {
        title: "新しい声に挑戦する仲間がいます",
        description: "Voice Challenger",
        community_message: "音程や声の出し方に向き合いながら、自分の声を育てている仲間がいます。挑戦する姿勢そのものが魅力です。",
        member_count: 17
      },
      groove_builder: {
        title: "音楽の一体感を楽しむ仲間がいます",
        description: "Groove Builder",
        community_message: "自分だけのグルーヴを探している仲間がいます。歌い方に正解はありません。あなたらしい成長スタイルを見つけていきましょう。",
        member_count: 12
      }
    }.freeze

    def self.call(customer = nil, growth_type: nil)
      new(customer, growth_type: growth_type).call
    end

    def initialize(customer = nil, growth_type: nil)
      @customer = customer
      @growth_type = growth_type
    end

    def call
      copy = COPY_BY_TYPE.fetch(growth_type_key, fallback_copy)

      GrowthTypeCommunity.new(
        growth_type_key: growth_type_key,
        title: copy[:title],
        description: copy[:description],
        community_message: copy[:community_message],
        member_count: copy[:member_count],
        cta_label: cta_label,
        cta_url: COMMUNITY_URL
      )
    end

    private

    def growth_type_key
      @growth_type_key ||= @growth_type&.type_key&.to_sym || :unknown
    end

    def cta_label
      growth_type_key == :unknown ? "コミュニティを見る" : "仲間を見てみる"
    end

    def fallback_copy
      {
        title: "あなたらしい成長を見つける仲間がいます",
        description: "Growth Community",
        community_message: "歌い方に正解はありません。あなたらしい成長スタイルを、音楽を楽しむ仲間と少しずつ見つけていきましょう。",
        member_count: 7
      }
    end
  end
end
