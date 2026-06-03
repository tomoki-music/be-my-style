module Singing
  class ProfileOgpBuilder
    DEFAULT_IMAGE_ASSET = "acguitar-girl.jpg".freeze
    SITE_SUFFIX         = "BeMyStyle Singing".freeze

    ProfileOgp = Struct.new(
      :title,
      :description,
      :image_asset_name,
      :url,
      keyword_init: true
    )

    def self.call(user, music_journey_timeline, base_url:)
      new(user, music_journey_timeline, base_url: base_url).call
    end

    def initialize(user, music_journey_timeline, base_url:)
      @user                   = user
      @music_journey_timeline = music_journey_timeline
      @base_url               = base_url
    end

    def call
      return fallback_ogp if @user.nil?

      ProfileOgp.new(
        title:            build_title,
        description:      build_description,
        image_asset_name: DEFAULT_IMAGE_ASSET,
        url:              "#{@base_url}/singing/users/#{@user.id}"
      )
    end

    private

    def build_title
      name = @user.name.presence
      if name.present?
        "🎵 #{name}のMusic Journey | #{SITE_SUFFIX}"
      else
        "🎵 Music Journey | #{SITE_SUFFIX}"
      end
    end

    def build_description
      items = timeline_items
      return "歌を楽しみながら成長する音楽コミュニティです。" if items.blank?

      if items.any? { |i| i.type == :personal_best }
        "自己ベストを更新しながら、自分らしい歌を育てています。"
      elsif items.any? { |i| i.type == :streak_milestone }
        "コツコツ続けながら、自分らしい歌を育てています。"
      else
        "ここから音楽の旅をはじめました。"
      end
    end

    def timeline_items
      return [] if @music_journey_timeline.nil?

      @music_journey_timeline.timeline_items
    rescue StandardError
      []
    end

    def fallback_ogp
      ProfileOgp.new(
        title:            "🎵 Music Journey | #{SITE_SUFFIX}",
        description:      "歌を楽しみながら成長する音楽コミュニティです。",
        image_asset_name: DEFAULT_IMAGE_ASSET,
        url:              nil
      )
    end
  end
end
