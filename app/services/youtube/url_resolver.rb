module Youtube
  # 楽曲リクエストのYouTube URL(単一文字列)からvideo_idを安全に抽出し、
  # canonical URL・サムネイルURLを算出する。HTML生成・DBアクセス・外部通信は行わない。
  #
  # Chat::LinkDetectorとは別実装(自由文中の複数URLスキャンという別責務のため、
  # 意図的に共有せず独立させている)。ホスト判定は部分一致(include?)ではなく
  # 完全一致allowlistで行い、`youtube.com.evil.example`のような偽装ドメインを除外する。
  class UrlResolver
    ALLOWED_HOSTS = %w[youtube.com www.youtube.com m.youtube.com music.youtube.com youtu.be].freeze
    ALLOWED_SCHEMES = %w[http https].freeze
    VIDEO_ID_PATTERN = /\A[a-zA-Z0-9_-]{11}\z/.freeze

    Result = Struct.new(:video_id, :canonical_url, :thumbnail_url, keyword_init: true)

    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url.to_s.strip
    end

    def call
      video_id = extract_video_id
      return nil if video_id.nil?

      Result.new(
        video_id: video_id,
        canonical_url: "https://www.youtube.com/watch?v=#{video_id}",
        thumbnail_url: "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg"
      )
    end

    private

    def extract_video_id
      return nil if @url.blank?

      uri = safe_parse(@url)
      return nil if uri.nil?

      host = uri.host.to_s.downcase
      return nil unless ALLOWED_SCHEMES.include?(uri.scheme) && ALLOWED_HOSTS.include?(host)

      video_id = host == "youtu.be" ? video_id_from_short_path(uri) : video_id_from_youtube_com(uri)
      video_id if video_id&.match?(VIDEO_ID_PATTERN)
    end

    def safe_parse(raw_url)
      uri = URI.parse(raw_url)
      uri.is_a?(URI::HTTP) ? uri : nil
    rescue URI::InvalidURIError
      nil
    end

    def video_id_from_short_path(uri)
      match = uri.path.match(%r{\A/([a-zA-Z0-9_-]{11})\z})
      match && match[1]
    end

    def video_id_from_youtube_com(uri)
      if uri.path == "/watch"
        video_id_from_query(uri)
      elsif (match = uri.path.match(%r{\A/(?:shorts|embed|live)/([a-zA-Z0-9_-]{11})\z}))
        match[1]
      end
    end

    def video_id_from_query(uri)
      return nil if uri.query.blank?

      URI.decode_www_form(uri.query).to_h["v"]
    end
  end
end
