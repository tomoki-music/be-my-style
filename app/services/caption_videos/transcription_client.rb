require "net/http"
require "uri"
require "json"
require "securerandom"

module CaptionVideos
  # OpenAI Audio Transcriptions API (whisper-1) のクライアント。
  # SingingDiagnoses::OpenAiResponsesClient と同じ思想(Net::HTTP直叩き、
  # ENV優先→Rails credentialsフォールバック、型付き例外)で実装し、新規gemは追加しない。
  class TranscriptionClient
    class ConfigurationError < StandardError; end
    class RequestError < StandardError; end
    class TimeoutError < RequestError; end
    class ResponseFormatError < RequestError; end

    DEFAULT_ENDPOINT_URL = "https://api.openai.com/v1/audio/transcriptions".freeze
    DEFAULT_MODEL = "whisper-1".freeze
    DEFAULT_TIMEOUT = 120

    def initialize(api_key: nil, model: nil, endpoint_url: nil, timeout: nil, http_class: Net::HTTP)
      @api_key = api_key.presence || configured_api_key
      @model = model.presence || configured_model
      @endpoint_url = endpoint_url.presence || configured_endpoint_url
      @timeout = timeout || configured_timeout
      @http_class = http_class
    end

    # audio_path: ローカル一時ファイルのパス。language: ISO 639-1 (例: "ja")
    # 戻り値: [{ start: Float, end: Float, text: String }, ...] (segment単位)
    def transcribe(audio_path:, language: "ja")
      raise ConfigurationError, "OpenAI API key is not configured. Set OPENAI_API_KEY or credentials openai.api_key." if api_key.blank?
      raise RequestError, "audio file not found" unless File.exist?(audio_path)

      uri = URI.parse(endpoint_url)
      boundary = SecureRandom.hex(16)
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = build_multipart_body(boundary, audio_path, language)

      response = http_for(uri).request(request)
      parse_response(response)
    rescue URI::InvalidURIError => e
      raise ConfigurationError, "OpenAI endpoint URL is invalid: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      raise TimeoutError, "OpenAI transcription request timed out: #{e.class}"
    rescue SocketError, SystemCallError => e
      raise RequestError, "OpenAI transcription connection error: #{e.class}"
    end

    private

    attr_reader :api_key, :model, :endpoint_url, :timeout, :http_class

    def configured_api_key
      ENV["OPENAI_API_KEY"].presence ||
        Rails.application.credentials.dig(:openai, :api_key)
    end

    def configured_model
      ENV["OPENAI_TRANSCRIPTION_MODEL"].presence ||
        Rails.application.credentials.dig(:openai, :transcription_model) ||
        DEFAULT_MODEL
    end

    def configured_endpoint_url
      ENV["OPENAI_TRANSCRIPTION_URL"].presence || DEFAULT_ENDPOINT_URL
    end

    def configured_timeout
      ENV["OPENAI_TRANSCRIPTION_TIMEOUT_SECONDS"].presence&.to_i ||
        Rails.application.credentials.dig(:openai, :transcription_timeout_seconds)&.to_i ||
        DEFAULT_TIMEOUT
    end

    def http_for(uri)
      http = http_class.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout
      http.read_timeout = timeout
      http
    end

    def build_multipart_body(boundary, audio_path, language)
      body = +"".b
      body << form_field(boundary, "model", model)
      body << form_field(boundary, "response_format", "verbose_json")
      body << form_field(boundary, "language", language) if language.present?
      body << form_field(boundary, "timestamp_granularities[]", "segment")
      body << file_field(boundary, "file", audio_path)
      body << "--#{boundary}--\r\n".b
      body
    end

    def form_field(boundary, name, value)
      (
        "--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n" \
        "#{value}\r\n"
      ).b
    end

    def file_field(boundary, name, path)
      filename = File.basename(path)
      header = (
        "--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"\r\n" \
        "Content-Type: audio/mpeg\r\n\r\n"
      ).b
      header + File.binread(path) + "\r\n".b
    end

    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        raise RequestError, "OpenAI transcription request failed with status #{response.code}"
      end

      body = JSON.parse(response.body)
      segments = body["segments"]
      raise ResponseFormatError, "OpenAI response did not include segments" unless segments.is_a?(Array)

      segments.filter_map do |seg|
        text = seg["text"].to_s.strip
        next if text.blank?

        { start: seg["start"].to_f, end: seg["end"].to_f, text: text }
      end
    rescue JSON::ParserError => e
      raise ResponseFormatError, "OpenAI returned invalid JSON: #{e.message}"
    end
  end
end
