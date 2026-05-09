module Learning
  class LineWebhookProcessor
    Result = Struct.new(:status, :message, :processed_count, :connected_count, keyword_init: true) do
      def success?
        status == :ok
      end
    end

    NOT_CONFIGURED_MESSAGE = "LINE webhook secret is not configured".freeze
    INVALID_SIGNATURE_MESSAGE = "LINE webhook signature is invalid".freeze
    INVALID_JSON_MESSAGE = "LINE webhook payload is invalid".freeze

    def initialize(channel_secret: ENV["LINE_CHANNEL_SECRET"].to_s)
      @channel_secret = channel_secret
    end

    def configured?
      @channel_secret.present?
    end

    def process(raw_body:, signature:)
      return Result.new(status: :not_configured, message: NOT_CONFIGURED_MESSAGE, processed_count: 0, connected_count: 0) unless configured?
      return Result.new(status: :invalid_signature, message: INVALID_SIGNATURE_MESSAGE, processed_count: 0, connected_count: 0) unless valid_signature?(raw_body, signature)

      events = JSON.parse(raw_body).fetch("events", [])
      connected_count = events.count { |event| connect_from_event(event) }

      Result.new(status: :ok, message: "ok", processed_count: events.size, connected_count: connected_count)
    rescue JSON::ParserError
      Result.new(status: :invalid_payload, message: INVALID_JSON_MESSAGE, processed_count: 0, connected_count: 0)
    end

    def valid_signature?(raw_body, signature)
      return false if signature.blank?

      expected = Base64.strict_encode64(
        OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), @channel_secret, raw_body)
      )
      secure_compare(expected, signature)
    end

    private

    def connect_from_event(event)
      line_user_id = event.dig("source", "userId").to_s
      token = token_from_event(event)
      return false if line_user_id.blank? || token.blank?

      connection = LineConnection.find_by_active_token(token)
      return false unless connection

      connection.complete_connection!(
        line_user_id: line_user_id,
        display_name: connection.learning_student&.display_name
      )
      true
    end

    def token_from_event(event)
      token_from_postback(event) || token_from_message(event)
    end

    def token_from_postback(event)
      return unless event["type"] == "postback"

      data = Rack::Utils.parse_nested_query(event.dig("postback", "data").to_s)
      data["token"].presence
    end

    def token_from_message(event)
      return unless event["type"] == "message"
      return unless event.dig("message", "type") == "text"

      text = event.dig("message", "text").to_s
      text[/token=([A-Za-z0-9\-_]+)/, 1] || text[/\A[A-Za-z0-9\-_]{20,}\z/]
    end

    def secure_compare(expected, actual)
      return false unless expected.bytesize == actual.to_s.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, actual.to_s)
    end
  end
end
