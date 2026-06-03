module Singing
  class JourneyShareBuilder
    JourneyShare = Struct.new(
      :share_title,
      :share_text,
      :share_url,
      :x_share_url,
      :copy_text,
      :visible,
      keyword_init: true
    )

    def self.call(current_customer, profile_user, music_journey_timeline, base_url:)
      new(current_customer, profile_user, music_journey_timeline, base_url: base_url).call
    end

    def initialize(current_customer, profile_user, music_journey_timeline, base_url:)
      @current_customer       = current_customer
      @profile_user           = profile_user
      @music_journey_timeline = music_journey_timeline
      @base_url               = base_url
    end

    def call
      unless visible?
        return JourneyShare.new(
          share_title:  nil,
          share_text:   nil,
          share_url:    nil,
          x_share_url:  nil,
          copy_text:    nil,
          visible:      false
        )
      end

      url  = profile_url
      text = build_share_text
      JourneyShare.new(
        share_title: "あなたの音楽の歩みをシェアしよう",
        share_text:  text,
        share_url:   url,
        x_share_url: x_share_url(text, url),
        copy_text:   url,
        visible:     true
      )
    end

    private

    def visible?
      return false if @current_customer.nil?
      return false if @profile_user.nil?
      return false unless @current_customer == @profile_user
      return false if @music_journey_timeline.nil?
      return false if @music_journey_timeline.timeline_items.blank?

      true
    end

    def profile_url
      "#{@base_url}/singing/users/#{@profile_user.id}"
    end

    def x_share_url(text, url)
      encoded_text = CGI.escape("#{text}\n#{url}")
      "https://x.com/intent/tweet?text=#{encoded_text}"
    end

    def build_share_text
      items = @music_journey_timeline.timeline_items

      highlight = if items.any? { |i| i.type == :personal_best }
        "自己ベストを更新しながら"
      elsif items.any? { |i| i.type == :streak_milestone }
        "コツコツ続けながら"
      else
        "ここから音楽の旅をはじめました"
      end

      "🎵 私のMusic Journey\n\n#{highlight}、少しずつ歌を楽しんでいます。\n\nBeMyStyle Singingで、自分らしい歌を育てています。"
    end
  end
end
