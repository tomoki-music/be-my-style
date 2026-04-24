module SingingDiagnoses
  class GenerateAiCommentJob < ApplicationJob
    queue_as :default

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
    rescue StandardError => e
      diagnosis&.update!(
        ai_comment_status: :ai_comment_failed,
        ai_comment_failure_reason: "#{e.class}: #{e.message}".truncate(500)
      )
    end
  end
end
