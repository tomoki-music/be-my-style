module Singing
  class CircleMembersDiscoveryBuilder
    CircleMembersDiscovery = Struct.new(
      :circle_slug,
      :circle_name,
      :circle_description,
      :members_count,
      :empty_title,
      :empty_message,
      keyword_init: true
    )

    CIRCLE_CONFIGS = {
      emotional_singer: {
        name:          "🎭 Emotional Singer Circle",
        description:   "表現を大切にしながら、自分らしい歌を育てる仲間たちです。",
        members_count: 23,
        empty_title:   "まだこのCircleの仲間は少ないようです。",
        empty_message: "まずはあなたの診断や挑戦を重ねて、音楽の輪を少しずつ広げていきましょう。"
      },
      rhythm_explorer: {
        name:          "🥁 Rhythm Explorer Circle",
        description:   "リズムやノリを楽しみながら、音楽の土台を育てる仲間たちです。",
        members_count: 18,
        empty_title:   "まだこのCircleの仲間は少ないようです。",
        empty_message: "まずはあなたの診断や挑戦を重ねて、音楽の輪を少しずつ広げていきましょう。"
      },
      consistency_hero: {
        name:          "🔥 Consistency Circle",
        description:   "コツコツ続けながら、歌との時間を積み重ねている仲間たちです。",
        members_count: 31,
        empty_title:   "まだこのCircleの仲間は少ないようです。",
        empty_message: "まずはあなたの診断や挑戦を重ねて、音楽の輪を少しずつ広げていきましょう。"
      },
      voice_challenger: {
        name:          "🎤 Voice Challenge Circle",
        description:   "声の可能性に挑戦しながら、新しい自分の歌を探している仲間たちです。",
        members_count: 15,
        empty_title:   "まだこのCircleの仲間は少ないようです。",
        empty_message: "まずはあなたの診断や挑戦を重ねて、音楽の輪を少しずつ広げていきましょう。"
      },
      dynamic_performer: {
        name:          "🌟 Dynamic Performer Circle",
        description:   "歌の表現力やステージ感を楽しみながら成長している仲間たちです。",
        members_count: 12,
        empty_title:   "まだこのCircleの仲間は少ないようです。",
        empty_message: "まずはあなたの診断や挑戦を重ねて、音楽の輪を少しずつ広げていきましょう。"
      },
      groove_builder: {
        name:          "🎵 Groove Builder Circle",
        description:   "グルーヴや音楽の流れを感じながら、歌を楽しむ仲間たちです。",
        members_count: 20,
        empty_title:   "まだこのCircleの仲間は少ないようです。",
        empty_message: "まずはあなたの診断や挑戦を重ねて、音楽の輪を少しずつ広げていきましょう。"
      }
    }.freeze

    FALLBACK_CONFIG = {
      name:          "🎵 Singing Members",
      description:   "歌を楽しみながら成長しているメンバーたちです。",
      members_count: 0,
      empty_title:   "最近活動しているメンバーが見つかりませんでした。",
      empty_message: "音楽を楽しみながら、仲間と出会いましょう。"
    }.freeze

    def self.call(circle_slug, members_count: nil)
      new(circle_slug, members_count: members_count).call
    end

    def initialize(circle_slug, members_count: nil)
      @circle_slug            = circle_slug.presence
      @members_count_override = members_count
    end

    def call
      config = find_config
      CircleMembersDiscovery.new(
        circle_slug:        @circle_slug,
        circle_name:        config[:name],
        circle_description: config[:description],
        members_count:      @members_count_override || config[:members_count],
        empty_title:        config[:empty_title],
        empty_message:      config[:empty_message]
      )
    end

    def valid_circle?
      @circle_slug.present? && CIRCLE_CONFIGS.key?(@circle_slug.to_sym)
    end

    private

    def find_config
      return FALLBACK_CONFIG if @circle_slug.blank?

      CIRCLE_CONFIGS[@circle_slug.to_sym] || FALLBACK_CONFIG
    end
  end
end
