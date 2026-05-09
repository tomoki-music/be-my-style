module Learning
  class LineNotificationAdapter
    Result = Struct.new(:status, :message, :payload, keyword_init: true) do
      def success?
        status == :ok
      end
    end

    NOT_CONFIGURED_MESSAGE = "LINE adapter is not configured".freeze
    DRY_RUN_MESSAGE = "LINE adapter dry run only".freeze

    def enabled?
      channel_access_token.present?
    end

    def deliver(notification_log)
      payload = build_payload(notification_log)

      unless enabled?
        notification_log.update!(error_message: NOT_CONFIGURED_MESSAGE)
        return Result.new(status: :adapter_disabled, message: NOT_CONFIGURED_MESSAGE, payload: payload)
      end

      Result.new(status: :dry_run, message: DRY_RUN_MESSAGE, payload: payload)
    end

    def build_payload(notification_log)
      {
        to: notification_log.learning_student_id,
        messages: [
          {
            type: "text",
            text: notification_text(notification_log)
          }
        ]
      }
    end

    private

    def notification_text(notification_log)
      [
        notification_log.title,
        notification_log.message,
        notification_log.recommended_action.presence && "おすすめ: #{notification_log.recommended_action}"
      ].compact.join("\n")
    end

    def channel_access_token
      @channel_access_token ||= begin
        env_token = ENV["LINE_CHANNEL_ACCESS_TOKEN"].to_s
        env_token.presence || credentials_token.to_s
      end
    end

    def credentials_token
      Rails.application.credentials.dig(:line, :channel_access_token)
    rescue NoMethodError, KeyError
      nil
    end
  end
end
