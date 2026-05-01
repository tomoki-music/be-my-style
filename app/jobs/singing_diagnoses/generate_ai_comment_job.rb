module SingingDiagnoses
  class GenerateAiCommentJob < ApplicationJob
    queue_as :default

    DEVELOPMENT_FALLBACK_COMMENT = "[開発環境] OpenAI APIキーが未設定のため、本番用AIコメントを生成できません。本番環境ではAPIキーを設定することで実際のコメントが生成されます。".freeze

    def perform(diagnosis_id)
      diagnosis = SingingDiagnosis.includes(:customer).find_by(id: diagnosis_id)
      return if diagnosis.blank?
      return unless diagnosis.completed?
      return unless diagnosis.customer&.has_feature?(:singing_diagnosis_ai_comment)

      diagnosis.update!(
        ai_comment_status: :ai_comment_processing,
        ai_comment_failure_reason: nil
      )

      comment = AiCommentGenerator.call(diagnosis)

      diagnosis.update!(
        ai_comment: comment,
        ai_comment_status: :ai_comment_completed,
        ai_comment_failure_reason: nil,
        ai_commented_at: Time.current
      )
    rescue OpenAiResponsesClient::ConfigurationError => e
      Rails.logger.error("[GenerateAiCommentJob] ConfigurationError: diagnosis_id=#{diagnosis_id} error=#{e.message}")
      if Rails.env.development?
        Rails.logger.warn("[GenerateAiCommentJob] Using development fallback comment: diagnosis_id=#{diagnosis_id}")
        diagnosis&.update!(
          ai_comment: DEVELOPMENT_FALLBACK_COMMENT,
          ai_comment_status: :ai_comment_completed,
          ai_comment_failure_reason: nil,
          ai_commented_at: Time.current
        )
      else
        diagnosis&.update!(
          ai_comment_status: :ai_comment_failed,
          ai_comment_failure_reason: e.message.truncate(500)
        )
      end
    rescue StandardError => e
      Rails.logger.error("[GenerateAiCommentJob] Failed: diagnosis_id=#{diagnosis_id} error=#{e.class}: #{e.message}")
      diagnosis&.update!(
        ai_comment_status: :ai_comment_failed,
        ai_comment_failure_reason: "#{e.class}: #{e.message}".truncate(500)
      )
    end
  end
end
