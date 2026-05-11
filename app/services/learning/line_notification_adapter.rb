require "net/http"

module Learning
  class LineNotificationAdapter
    PUSH_ENDPOINT = URI("https://api.line.me/v2/bot/message/push").freeze
    REPLY_ENDPOINT = URI("https://api.line.me/v2/bot/message/reply").freeze

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

    def reply(reply_token:, text:)
      payload = {
        replyToken: reply_token,
        messages: [
          {
            type: "text",
            text: text
          }
        ]
      }

      return Result.new(status: :adapter_disabled, message: NOT_CONFIGURED_MESSAGE, payload: payload) unless enabled?
      return Result.new(status: :no_recipient, message: NO_RECIPIENT_MESSAGE, payload: payload) if reply_token.blank?

      response = @http_client.start(REPLY_ENDPOINT.host, REPLY_ENDPOINT.port, use_ssl: true) do |http|
        http.request(build_request(payload, endpoint: REPLY_ENDPOINT))
      end

      if response.is_a?(Net::HTTPSuccess)
        Result.new(status: :ok, message: "LINE reply message sent", payload: payload)
      else
        Result.new(status: :http_error, message: "#{HTTP_ERROR_MESSAGE}: status=#{response.code}", payload: payload)
      end
    rescue StandardError => e
      Result.new(status: :http_error, message: "#{HTTP_ERROR_MESSAGE}: #{e.class.name}", payload: payload)
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

    def build_request(payload, endpoint: PUSH_ENDPOINT)
      request = Net::HTTP::Post.new(endpoint)
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
      case notification_log.notification_type
      when "reminder"
        reminder_text(notification_log)
      when "teacher_message"
        teacher_message_text(notification_log)
      when "teacher_bulk_message"
        teacher_bulk_message_text(notification_log)
      when "followup_message"
        followup_message_text(notification_log)
      when "assignment_created"
        assignment_created_text(notification_log)
      when "auto_inactive_reminder"
        auto_inactive_reminder_text(notification_log)
      when "auto_assignment_due_reminder"
        auto_assignment_due_reminder_text(notification_log)
      when "auto_assignment_overdue_reminder"
        auto_assignment_overdue_reminder_text(notification_log)
      when "teacher_revision_request"
        teacher_revision_request_text(notification_log)
      when "teacher_action"
        action_text(notification_log)
      else
        default_text(notification_log)
      end
    end

    def reminder_text(notification_log)
      student = notification_log.learning_student
      [
        "今日の練習リマインドです！",
        streak_message_for(student),
        training_lines_for(student),
        notification_log.message,
        notification_log.recommended_action.presence && "おすすめ: #{notification_log.recommended_action}",
        "▼ 今日やることを見る",
        student_portal_url(student),
        "終わったらLINEで「やった」と返信してね。"
      ].flatten.compact.join("\n")
    end

    def action_text(notification_log)
      student = notification_log.learning_student
      [
        notification_log.title,
        notification_log.message,
        notification_log.recommended_action.presence,
        "▼ 生徒ページを開く",
        student_portal_url(student)
      ].compact.join("\n")
    end

    def teacher_message_text(notification_log)
      student = notification_log.learning_student
      [
        notification_log.title.presence || "先生からのメッセージです",
        notification_log.message,
        notification_log.recommended_action.presence,
        "▼ 生徒ページを開く",
        student_portal_url(student),
        "終わったらLINEで「やった」と返信してね。"
      ].compact.join("\n")
    end

    def teacher_bulk_message_text(notification_log)
      student = notification_log.learning_student
      truncate_line_text([
        "先生からのメッセージです。",
        notification_log.message,
        training_check_lines(notification_log),
        "▼ 生徒ページを見る",
        student_portal_url(student),
        "練習できたら「やった！」と返信してね。"
      ].flatten.compact.join("\n"))
    end

    def followup_message_text(notification_log)
      student = notification_log.learning_student
      [
        "先生から応援メッセージが届いています！",
        notification_log.message,
        "▼ 生徒ページを見る",
        student_portal_url(student),
        "終わったら「やった！」と返信してね。"
      ].compact.join("\n")
    end

    def assignment_created_text(notification_log)
      student = notification_log.learning_student
      truncate_line_text([
        "📘 新しい課題が届きました！",
        notification_log.title,
        notification_log.message,
        training_check_lines(notification_log),
        notification_log.recommended_action.presence,
        "▼ 生徒ページを見る",
        student_portal_url(student),
        "終わったら「やった！」と返信してね。"
      ].flatten.compact.join("\n"))
    end

    def auto_inactive_reminder_text(notification_log)
      student = notification_log.learning_student
      [
        "練習の様子を見にきました。",
        notification_log.message,
        notification_log.recommended_action.presence,
        "▼ 生徒ページを見る",
        student_portal_url(student),
        "できたらLINEで「やった」と返信してね。"
      ].compact.join("\n")
    end

    def auto_assignment_due_reminder_text(notification_log)
      student = notification_log.learning_student
      truncate_line_text([
        "課題の期限が近づいています。",
        notification_log.title,
        notification_log.message,
        training_check_lines(notification_log),
        notification_log.recommended_action.presence,
        "▼ 生徒ページを見る",
        student_portal_url(student),
        "終わったらLINEで「やった」と返信してね。"
      ].flatten.compact.join("\n"))
    end

    def auto_assignment_overdue_reminder_text(notification_log)
      student = notification_log.learning_student
      truncate_line_text([
        "未完了の課題があります。",
        notification_log.title,
        notification_log.message,
        training_check_lines(notification_log),
        notification_log.recommended_action.presence,
        "▼ 生徒ページを見る",
        student_portal_url(student),
        "終わったらLINEで「やった」と返信してね。"
      ].flatten.compact.join("\n"))
    end

    def teacher_revision_request_text(notification_log)
      student = notification_log.learning_student
      truncate_line_text([
        "先生から再チャレンジのコメントが届きました。",
        "「#{notification_log.message}」",
        notification_log.recommended_action.presence,
        training_check_lines(notification_log),
        "▼ 生徒ページを見る",
        student_portal_url(student),
        "できたら、もう一度「やった」と返信してください！"
      ].flatten.compact.join("\n"))
    end

    def default_text(notification_log)
      [
        notification_log.title,
        notification_log.message,
        notification_log.recommended_action.presence && "おすすめ: #{notification_log.recommended_action}",
        notification_log.learning_student && "▼ 生徒ページを開く",
        student_portal_url(notification_log.learning_student)
      ].compact.join("\n")
    end

    def training_lines_for(student)
      return nil unless student

      trainings = student.learning_student_trainings.ordered.limit(2).pluck(:title)
      return nil if trainings.blank?

      trainings.map { |title| "・#{title}" }
    end

    def training_check_lines(notification_log)
      training = assignment_for(notification_log)&.learning_student_training
      return nil unless training

      [
        training.check_method.present? && "確認方法: #{training.check_method}",
        training.achievement_criteria.present? && "達成の目安: #{training.achievement_criteria}",
        "誰に見てもらうか: #{training.judge_type_label}"
      ].compact
    end

    def assignment_for(notification_log)
      assignment_id = notification_log.metadata.to_h["learning_assignment_id"] ||
                      notification_log.metadata.to_h["assignment_id"]
      return if assignment_id.blank?

      LearningAssignment.includes(learning_student_training: :learning_training_master)
        .find_by(id: assignment_id, learning_student_id: notification_log.learning_student_id)
    end

    def truncate_line_text(text)
      text.to_s.truncate(500)
    end

    def streak_message_for(student)
      return "まずは5分だけでもOK！" unless student

      streak = student.learning_streak_days
      if streak >= 7
        "1週間継続達成！かなり良い習慣になってきています"
      elsif streak >= 3
        "#{streak}日継続中！いい流れです"
      else
        "まずは5分だけでもOK！"
      end
    end

    def student_portal_url(student)
      student&.portal_url
    end

    def channel_access_token
      @channel_access_token ||= ENV["LINE_CHANNEL_ACCESS_TOKEN"].to_s.presence
    end
  end
end
