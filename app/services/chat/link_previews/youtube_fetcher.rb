require "json"
require "net/http"
require "uri"

module Chat
  module LinkPreviews
    # YouTube oEmbedを使い、title/author_name/thumbnail_urlのみを取得する。
    # oEmbedの`html`フィールド(iframeを含む)は取得しても一切利用しない
    # (iframe/autoplayをチャットに持ち込まないため)。
    #
    # 接続先は常に固定ホスト(www.youtube.com)であり、投稿されたURLを直接fetchしない
    # ため、SSRFの主要リスク(任意ホストへの接続)は構造的に排除される。
    class YoutubeFetcher
      class RequestError < StandardError; end
      class TimeoutError < RequestError; end
      class ResponseFormatError < RequestError; end

      OEMBED_ENDPOINT = "https://www.youtube.com/oembed".freeze
      DEFAULT_TIMEOUT = 3
      MAX_RESPONSE_BYTES = 100 * 1024

      def self.call(url)
        new.call(url)
      end

      def initialize(timeout: nil, http_class: Net::HTTP)
        @timeout = timeout || configured_timeout
        @http_class = http_class
      end

      def call(url)
        uri = build_oembed_uri(url)
        response = http_for(uri).request(Net::HTTP::Get.new(uri.request_uri))
        parse_response(response)
      rescue URI::InvalidURIError => e
        raise RequestError, "YouTube oEmbed request URL is invalid: #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
        raise TimeoutError, "YouTube oEmbed request timed out: #{e.class}: #{e.message}"
      rescue SocketError, SystemCallError => e
        raise RequestError, "YouTube oEmbed connection error: #{e.class}: #{e.message}"
      end

      private

      attr_reader :timeout, :http_class

      def configured_timeout
        ENV["YOUTUBE_OEMBED_TIMEOUT_SECONDS"].presence&.to_i || DEFAULT_TIMEOUT
      end

      def build_oembed_uri(url)
        uri = URI.parse(OEMBED_ENDPOINT)
        uri.query = URI.encode_www_form(url: url, format: "json")
        uri
      end

      def http_for(uri)
        http = http_class.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout
        http.read_timeout = timeout
        http
      end

      def parse_response(response)
        unless response.is_a?(Net::HTTPSuccess)
          raise RequestError, "YouTube oEmbed request failed with status #{response.code}"
        end

        body = response.body.to_s
        raise ResponseFormatError, "YouTube oEmbed response too large" if body.bytesize > MAX_RESPONSE_BYTES

        json = JSON.parse(body)
        {
          title: json["title"],
          author_name: json["author_name"],
          thumbnail_url: json["thumbnail_url"]
        }
      rescue JSON::ParserError => e
        raise ResponseFormatError, "YouTube oEmbed returned invalid JSON: #{e.message}"
      end
    end
  end
end
