require "json"
require "net/http"
require "uri"

module SingingDiagnoses
  class AnalyzerClient
    class ConfigurationError < StandardError; end
    class RequestError < StandardError; end

    DEFAULT_TIMEOUT = 10
    DEFAULT_DEVELOPMENT_ENDPOINT_URL = "http://localhost:8000/diagnoses".freeze
    CONFIGURATION_ERROR_MESSAGE = [
      "singing analyzer endpoint is not configured.",
      "Set SINGING_ANALYZER_DIAGNOSES_URL or credentials singing_analyzer.diagnoses_url."
    ].join(" ").freeze

    def initialize(endpoint_url: nil, open_timeout: nil, read_timeout: nil, http_class: Net::HTTP)
      @endpoint_url = endpoint_url.presence || configured_endpoint_url
      @open_timeout = open_timeout || configured_timeout(:open_timeout)
      @read_timeout = read_timeout || configured_timeout(:read_timeout)
      @http_class = http_class
    end

    def submit(diagnosis)
      raise ConfigurationError, CONFIGURATION_ERROR_MESSAGE if endpoint_url.blank?
      raise RequestError, "audio_file is not attached" unless diagnosis.audio_file.attached?

      uri = URI.parse(endpoint_url)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = nil

      Rails.logger.info("Singing analyzer request started: diagnosis_id=#{diagnosis.id} endpoint=#{endpoint_url}") if defined?(Rails)

      diagnosis.audio_file.blob.open do |file|
        request.set_form(form_parts(diagnosis, file), "multipart/form-data")

        response = http_for(uri).request(request)
      end

      parse_response(response).tap do
        Rails.logger.info("Singing analyzer request succeeded: diagnosis_id=#{diagnosis.id} status=#{response.code}") if defined?(Rails)
      end
    end

    private

    attr_reader :endpoint_url, :open_timeout, :read_timeout, :http_class

    def configured_endpoint_url
      ENV["SINGING_ANALYZER_DIAGNOSES_URL"].presence ||
        Rails.application.credentials.dig(:singing_analyzer, :diagnoses_url) ||
        development_endpoint_url
    end

    def configured_timeout(key)
      ENV["SINGING_ANALYZER_TIMEOUT_SECONDS"].presence&.to_i ||
        Rails.application.credentials.dig(:singing_analyzer, key)&.to_i ||
        DEFAULT_TIMEOUT
    end

    def development_endpoint_url
      return unless defined?(Rails) && Rails.env.development?

      DEFAULT_DEVELOPMENT_ENDPOINT_URL
    end

    def form_parts(diagnosis, file)
      blob = diagnosis.audio_file.blob
      reference_input = diagnosis.reference_input
      parts = [
        ["diagnosis_id", diagnosis.id.to_s],
        ["performance_type", diagnosis.performance_type.to_s],
        ["song_title", diagnosis.song_title.to_s],
        ["memo", diagnosis.memo.to_s],
        [
          "audio_file",
          file,
          {
            filename: blob.filename.to_s,
            content_type: blob.content_type.presence || "application/octet-stream"
          }
        ]
      ]

      if reference_input.respond_to?(:[])
        reference_key = reference_input[:reference_key] || reference_input["reference_key"]
        reference_bpm = reference_input[:reference_bpm] || reference_input["reference_bpm"]
        parts << ["reference_key", reference_key.to_s] if reference_key.present?
        parts << ["reference_bpm", reference_bpm.to_s] if reference_bpm.present?
      end

      parts
    end

    def http_for(uri)
      http = http_class.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout
      http
    end

    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        raise RequestError, "analyzer request failed with status #{response.code}: #{response.body.to_s.truncate(200)}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise RequestError, "analyzer returned invalid JSON: #{e.message}"
    end
  end
end
