module Learning
  class LineWebhookProcessor
    Result = Struct.new(:status, :message, :processed_count, :connected_count, :reaction_count, keyword_init: true) do
      def success?
        status == :ok
      end
    end

    NOT_CONFIGURED_MESSAGE = "LINE webhook secret is not configured".freeze
    INVALID_SIGNATURE_MESSAGE = "LINE webhook signature is invalid".freeze
    INVALID_JSON_MESSAGE = "LINE webhook payload is invalid".freeze
    TEACHER_REVIEW_REPLY_MESSAGE = "報告ありがとう！このトレーニングは先生確認が必要です。先生の確認後に完了になります。".freeze
    REACTION_NOTIFICATION_TYPES = %w[
      reminder
      teacher_action
      teacher_bulk_message
      teacher_message
      followup_message
      assignment_created
      auto_assignment_due_reminder
      auto_assignment_overdue_reminder
    ].freeze

    def initialize(channel_secret: ENV["LINE_CHANNEL_SECRET"].to_s, line_adapter: LineNotificationAdapter.new)
      @channel_secret = channel_secret
      @line_adapter = line_adapter
    end

    def configured?
      @channel_secret.present?
    end

    def process(raw_body:, signature:)
      return empty_result(:not_configured, NOT_CONFIGURED_MESSAGE) unless configured?
      return empty_result(:invalid_signature, INVALID_SIGNATURE_MESSAGE) unless valid_signature?(raw_body, signature)

      events = JSON.parse(raw_body).fetch("events", [])
      connected_count = events.count { |event| connect_from_event(event) }
      reaction_count = events.count { |event| record_reaction_from_event(event) }

      Result.new(status: :ok, message: "ok", processed_count: events.size, connected_count: connected_count, reaction_count: reaction_count)
    rescue JSON::ParserError
      empty_result(:invalid_payload, INVALID_JSON_MESSAGE)
    end

    def valid_signature?(raw_body, signature)
      return false if signature.blank?

      expected = Base64.strict_encode64(
        OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), @channel_secret, raw_body)
      )
      secure_compare(expected, signature)
    end

    private

    REACTION_KEYWORDS = %w[
      やった
      練習した
      練習しました
      ok
      完了
      できた
      おわった
      終わった
      done
    ].freeze

    def empty_result(status, message)
      Result.new(status: status, message: message, processed_count: 0, connected_count: 0, reaction_count: 0)
    end

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

    def record_reaction_from_event(event)
      text = text_message(event)
      reaction = reaction_message?(text)
      log_webhook_event(event, text: text, reaction: reaction)
      return false unless reaction

      connection = LineConnection.connected
        .includes(:learning_student)
        .where(line_user_id: event.dig("source", "userId").to_s)
        .order(connected_at: :desc)
        .first
      log_reaction_lookup(connection_found: connection.present?)
      student = connection&.learning_student
      return false unless student

      reply_message = nil
      ActiveRecord::Base.transaction do
        notification_log = latest_unreacted_notification_for(student)
        log_target_notification(notification_log)
        notification_log&.update!(
          reaction_received: true,
          reacted_at: Time.current,
          reaction_message: text.truncate(255)
        )
        reacted_assignment = handle_reacted_assignment!(student, notification_log, text)
        create_progress_log_from_reaction!(student, text, completed_assignment: reacted_assignment) unless reacted_assignment&.pending_review?
        reply_message = TEACHER_REVIEW_REPLY_MESSAGE if reacted_assignment&.pending_review?
        student.update!(last_learning_action_at: Time.current)
      end
      deliver_reaction_reply(event, reply_message) if reply_message.present?

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
      text = text_message(event)
      return unless text

      text[/token=([A-Za-z0-9\-_]+)/, 1] || text[/\A[A-Za-z0-9\-_]{20,}\z/]
    end

    def text_message(event)
      return unless event["type"] == "message"
      return unless event.dig("message", "type") == "text"

      event.dig("message", "text").to_s.strip
    end

    def reaction_message?(text)
      normalized_text = text.to_s.strip
      return false if normalized_text.blank?
      return false if normalized_text.match?(/token=/i)

      comparable_text = normalized_text.downcase
      REACTION_KEYWORDS.sort_by { |keyword| -keyword.length }.any? do |keyword|
        next false unless comparable_text.start_with?(keyword)

        reaction_suffix?(comparable_text.delete_prefix(keyword))
      end
    end

    def reaction_suffix?(suffix)
      suffix.blank? || suffix.match?(/\A[\s\p{P}\p{S}ー〜\u200d\ufe0f]*\z/)
    end

    def deliver_reaction_reply(event, message)
      reply_token = event["replyToken"].to_s.presence
      return if reply_token.blank?

      result = @line_adapter.reply(reply_token: reply_token, text: message)
      Rails.logger.info("[Learning::LineWebhookProcessor] teacher_review_reply=#{result.status}")
    end

    def latest_unreacted_notification_for(student)
      student.learning_notification_logs
        .where(delivery_channel: "line", status: "sent")
        .where(notification_type: REACTION_NOTIFICATION_TYPES)
        .where(reaction_received: [false, nil])
        .order(sent_at: :desc, created_at: :desc)
        .first
    end

    def create_progress_log_from_reaction!(student, text, completed_assignment: nil)
      return if student.learning_progress_logs.exists?(practiced_on: Time.zone.today)

      training = completed_assignment&.learning_student_training || student.learning_student_trainings.ordered.first
      student.learning_progress_logs.create!(
        customer: student.customer,
        learning_student_training: training,
        part: training&.part || student.main_part,
        training_title: training&.title || "LINE返信で練習報告",
        practiced_on: Time.zone.today,
        achievement_mark: "triangle",
        comment: "LINE返信から自動記録: #{text}"
      )
    end

    def handle_reacted_assignment!(student, notification_log, text)
      assignment = assignment_from_notification(student, notification_log) || latest_open_assignment(student)
      return unless assignment

      if assignment.teacher_review_required?
        assignment.mark_submitted_for_review!(message: text)
      else
        assignment.complete!
      end
      assignment
    end

    def assignment_from_notification(student, notification_log)
      assignment_id = notification_log&.metadata.to_h["learning_assignment_id"] ||
                      notification_log&.metadata.to_h["assignment_id"]
      return if assignment_id.blank?

      student.learning_assignments
        .where(status: LearningAssignment::OPEN_STATUSES)
        .find_by(id: assignment_id)
    end

    def latest_open_assignment(student)
      student.learning_assignments
        .where(status: LearningAssignment::OPEN_STATUSES)
        .order(created_at: :desc, id: :desc)
        .first
    end

    def log_webhook_event(event, text:, reaction:)
      Rails.logger.info(
        "[Learning::LineWebhookProcessor] event_type=#{event['type']} " \
        "message_text=#{safe_log_text(text).inspect} reaction=#{reaction}"
      )
    end

    def safe_log_text(text)
      text.to_s.gsub(/token=([A-Za-z0-9\-_]+)/, "token=[FILTERED]").truncate(50)
    end

    def log_reaction_lookup(connection_found:)
      Rails.logger.info("[Learning::LineWebhookProcessor] connection_found=#{connection_found}")
    end

    def log_target_notification(notification_log)
      details = []
      details << "target_notification_log_id=#{notification_log&.id || 'nil'}"
      Rails.logger.info("[Learning::LineWebhookProcessor] #{details.join(' ')}")
    end

    def secure_compare(expected, actual)
      return false unless expected.bytesize == actual.to_s.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, actual.to_s)
    end
  end
end
