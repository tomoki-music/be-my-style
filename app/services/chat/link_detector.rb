module Chat
  class LinkDetector
    MAX_LINKS = 3

    YOUTUBE_ALLOWED_HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be].freeze
    VIDEO_ID_PATTERN = /\A[a-zA-Z0-9_-]{11}\z/.freeze
    # /public/events/:id に完全一致する場合のみイベントカード対象とする(edit・admin・
    # 余分なパス・数値以外のIDは除外)。クエリ文字列・fragmentはuri.pathに含まれないため、
    # 付与されていても解決結果(event_id)には影響しない。
    EVENT_PATH_PATTERN = %r{\A/public/events/(\d+)\z}.freeze
    # Markdownリンク `[text](https://...)` の `)` や `]` はURLの一部になり得ないため、
    # あらかじめマッチ対象から除外する(スペース無しで後続文字が続く場合の誤爆を防ぐ)。
    URL_PATTERN = %r{https?://[^\s)\]]+}.freeze

    Detected = Struct.new(:url, :provider, :external_id, keyword_init: true)

    def self.call(content)
      new(content).call
    end

    def initialize(content)
      @content = content.to_s
    end

    def call
      results = []
      seen = {}

      @content.scan(URL_PATTERN).each do |raw_url|
        break if results.size >= MAX_LINKS

        candidate = build_candidate(raw_url)
        next if candidate.nil?

        key = [candidate.provider, candidate.external_id]
        next if seen[key]

        seen[key] = true
        results << candidate
      end

      results
    end

    private

    def build_candidate(raw_url)
      uri = safe_parse(raw_url)
      return nil if uri.nil?
      return nil unless uri.scheme == "https"

      host = uri.host.to_s.downcase

      if YOUTUBE_ALLOWED_HOSTS.include?(host)
        build_youtube_candidate(uri, host)
      elsif internal_host?(host)
        build_event_candidate(uri)
      end
    end

    def internal_host?(host)
      internal_hosts.include?(host)
    end

    # 設定不備(未設定・nil)でメッセージ投稿全体が500にならないよう、Array(...)で
    # 必ず配列を返す(config側でも正規化済みのArrayをfreezeして格納しているが、
    # ここでも二重に防御する)。
    def internal_hosts
      Array(Rails.application.config.x.chat_link_preview.internal_hosts)
    end

    def build_youtube_candidate(uri, host)
      video_id = extract_youtube_video_id(uri, host)
      return nil if video_id.nil?

      Detected.new(url: "https://www.youtube.com/watch?v=#{video_id}", provider: :youtube, external_id: video_id)
    end

    # 投稿時点で存在しないEventはカードを作らず、本文中の通常リンクとして扱う
    # (存在確認自体をここで行い、以降のsync/fetch層をイベントの有無で分岐させない)。
    def build_event_candidate(uri)
      match = uri.path.match(EVENT_PATH_PATTERN)
      return nil if match.nil?

      event_id = match[1]
      return nil unless Event.exists?(id: event_id)

      Detected.new(url: "https://#{internal_hosts.first}/public/events/#{event_id}", provider: :event, external_id: event_id)
    end

    def safe_parse(raw_url)
      URI.parse(raw_url)
    rescue URI::InvalidURIError
      nil
    end

    def extract_youtube_video_id(uri, host)
      if host == "youtu.be"
        match = uri.path.match(%r{\A/([a-zA-Z0-9_-]{11})\z})
        return match && match[1]
      end

      extract_from_youtube_com(uri)
    end

    # playlist(/playlist)は単一動画IDを持たないためMVPでは対象外とし、
    # watch/shorts/live/embedのみを対応させる。
    def extract_from_youtube_com(uri)
      if uri.path == "/watch"
        video_id_from_query(uri)
      elsif (match = uri.path.match(%r{\A/(?:shorts|live|embed)/([a-zA-Z0-9_-]{11})\z}))
        match[1]
      end
    end

    def video_id_from_query(uri)
      return nil if uri.query.blank?

      video_id = URI.decode_www_form(uri.query).to_h["v"]
      video_id if video_id&.match?(VIDEO_ID_PATTERN)
    end
  end
end
