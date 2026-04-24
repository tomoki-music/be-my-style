require "json"
require "net/http"
require "uri"

module SingingDiagnoses
  class OpenAiResponsesClient
    class ConfigurationError < StandardError; end
    class RequestError < StandardError; end

    DEFAULT_ENDPOINT_URL = "https://api.openai.com/v1/responses".freeze
    DEFAULT_MODEL = "gpt-4.1-mini".freeze
    DEFAULT_TIMEOUT = 20

    def initialize(api_key: nil, model: nil, endpoint_url: nil, timeout: nil, http_class: Net::HTTP)
      @api_key = api_key.presence || configured_api_key
      @model = model.presence || configured_model
      @endpoint_url = endpoint_url.presence || configured_endpoint_url
      @timeout = timeout || configured_timeout
      @http_class = http_class
    end

    def generate_text(input:, instructions:, max_output_tokens: 500)
      raise ConfigurationError, "OpenAI API key is not configured. Set OPENAI_API_KEY or credentials openai.api_key." if api_key.blank?

      uri = URI.parse(endpoint_url)
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = {
        model: model,
        instructions: instructions,
        input: input,
        max_output_tokens: max_output_tokens
      }.to_json

      response = http_for(uri).request(request)
      parse_response(response)
    end

    private

    attr_reader :api_key, :model, :endpoint_url, :timeout, :http_class

    def configured_api_key
      ENV["OPENAI_API_KEY"].presence ||
        Rails.application.credentials.dig(:openai, :api_key)
    end

    def configured_model
      ENV["OPENAI_SINGING_AI_COMMENT_MODEL"].presence ||
        Rails.application.credentials.dig(:openai, :singing_ai_comment_model) ||
        DEFAULT_MODEL
    end

    def configured_endpoint_url
      ENV["OPENAI_RESPONSES_URL"].presence || DEFAULT_ENDPOINT_URL
    end

    def configured_timeout
      ENV["OPENAI_TIMEOUT_SECONDS"].presence&.to_i ||
        Rails.application.credentials.dig(:openai, :timeout_seconds)&.to_i ||
        DEFAULT_TIMEOUT
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
        raise RequestError, "OpenAI request failed with status #{response.code}: #{response.body.to_s.truncate(500)}"
      end

      body = JSON.parse(response.body)
      extract_text(body).presence || raise(RequestError, "OpenAI response did not include text output")
    rescue JSON::ParserError => e
      raise RequestError, "OpenAI returned invalid JSON: #{e.message}"
    end

    def extract_text(body)
      return body["output_text"] if body["output_text"].present?

      Array(body["output"]).filter_map do |item|
        Array(item["content"]).filter_map do |content|
          content["text"] || content.dig("text", "value")
        end
      end.flatten.join("\n").presence
    end
  end
end
