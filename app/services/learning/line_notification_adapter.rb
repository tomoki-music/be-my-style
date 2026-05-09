require "net/http"

module Learning
  class LineNotificationAdapter
    PUSH_ENDPOINT = URI("https://api.line.me/v2/bot/message/push").freeze

    Result = Struct.new(:status, :message, :payload, keyword_init: true) do
      def success?
        status == :ok
      end
    end

    NOT_CONFIGURED_MESSAGE = "LINE adapter is not configured".freeze
    DRY_RUN_MESSAGE = "LINE adapter dry run only".freeze
    NO_RECIPIENT_MESSAGE = "LINE recipient is not connected".freeze
    HTTP_ERROR_MESSAGE = "LINE push message failed".freeze

    def initialize(http_client: Net::HTTP)
      @http_client = http_client
    end

    def enabled?
      channel_access_token.present?
    end

    def deliver(notification_log)
      payload = build_payload(notification_log)

      unless enabled?
        notification_log.update!(status: "skipped", error_message: NOT_CONFIGURED_MESSAGE)
        return Result.new(status: :adapter_disabled, message: NOT_CONFIGURED_MESSAGE, payload: payload)
      end

      if payload[:to].blank?
        notification_log.update!(status: "skipped", error_message: NO_RECIPIENT_MESSAGE)
        return Result.new(status: :no_recipient, message: NO_RECIPIENT_MESSAGE, payload: payload)
      end

      push_message(notification_log, payload)
    end

    def build_payload(notification_log)
      {
        to: line_user_id_for(notification_log.learning_student),
        messages: [
          {
            type: "text",
            text: notification_text(notification_log)
          }
        ]
      }
    end

    private

    def push_message(notification_log, payload)
      response = @http_client.start(PUSH_ENDPOINT.host, PUSH_ENDPOINT.port, use_ssl: true) do |http|
        http.request(build_request(payload))
      end

      if response.is_a?(Net::HTTPSuccess)
        notification_log.update!(status: "sent", sent_at: Time.current, error_message: nil)
        Result.new(status: :ok, message: "LINE push message sent", payload: payload)
      else
        message = "#{HTTP_ERROR_MESSAGE}: status=#{response.code} body=#{response.body.to_s.truncate(500)}"
        notification_log.update!(status: "failed", error_message: message)
        Result.new(status: :http_error, message: message, payload: payload)
      end
    rescue StandardError => e
      message = "#{HTTP_ERROR_MESSAGE}: #{e.class.name}"
      notification_log.update!(status: "failed", error_message: message)
      Result.new(status: :http_error, message: message, payload: payload)
    end

    def build_request(payload)
      request = Net::HTTP::Post.new(PUSH_ENDPOINT)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{channel_access_token}"
      request.body = payload.to_json
      request
    end

    def line_user_id_for(student)
      return nil unless student

      student.learning_line_connections.connected.order(connected_at: :desc).pick(:line_user_id)
    end

    def notification_text(notification_log)
      [
        notification_log.title,
        notification_log.message,
        notification_log.recommended_action.presence && "おすすめ: #{notification_log.recommended_action}"
      ].compact.join("\n")
    end

    def channel_access_token
      @channel_access_token ||= ENV["LINE_CHANNEL_ACCESS_TOKEN"].to_s.presence
    end
  end
end
