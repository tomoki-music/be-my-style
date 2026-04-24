module SingingDiagnoses
  class ResultPersister
    SCORE_KEYS = %i[overall_score pitch_score rhythm_score expression_score].freeze

    def self.call(diagnosis, payload)
      new(diagnosis, payload).call
    end

    def initialize(diagnosis, payload)
      @diagnosis = diagnosis
      @payload = payload
    end

    def call
      return mark_failed("Invalid analyzer payload") unless valid_payload?

      diagnosis.update!(
        overall_score: normalized_score(:overall_score),
        pitch_score: normalized_score(:pitch_score),
        rhythm_score: normalized_score(:rhythm_score),
        expression_score: normalized_score(:expression_score),
        result_payload: payload,
        diagnosed_at: Time.current,
        status: :completed,
        failure_reason: nil
      )

      enqueue_ai_comment_if_available

      true
    rescue StandardError => e
      mark_failed("#{e.class}: #{e.message}")
    end

    private

    attr_reader :diagnosis, :payload

    def valid_payload?
      payload.is_a?(Hash) &&
        score_payload.is_a?(Hash) &&
        SCORE_KEYS.all? { |key| score_payload.key?(key) || score_payload.key?(key.to_s) }
    end

    def normalized_score(key)
      value = score_payload[key] || score_payload[key.to_s]
      Integer(value)
    end

    def score_payload
      @score_payload ||= payload[:common] || payload["common"] || payload
    end

    def enqueue_ai_comment_if_available
      return unless diagnosis.customer&.has_feature?(:singing_diagnosis_ai_comment)

      diagnosis.update!(
        ai_comment: nil,
        ai_comment_status: :ai_comment_queued,
        ai_comment_failure_reason: nil,
        ai_commented_at: nil
      )

      GenerateAiCommentJob.perform_later(diagnosis.id)
    end

    def mark_failed(reason)
      diagnosis.update!(status: :failed, failure_reason: reason)
      false
    end
  end
end
