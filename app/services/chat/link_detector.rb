module Chat
  class LinkDetector
    MAX_LINKS = 3

    ALLOWED_HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be].freeze
    VIDEO_ID_PATTERN = /\A[a-zA-Z0-9_-]{11}\z/.freeze
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
      return nil unless ALLOWED_HOSTS.include?(host)

      video_id = extract_youtube_video_id(uri, host)
      return nil if video_id.nil?

      Detected.new(url: "https://www.youtube.com/watch?v=#{video_id}", provider: :youtube, external_id: video_id)
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
