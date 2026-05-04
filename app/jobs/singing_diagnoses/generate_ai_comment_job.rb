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
    rescue OpenAiResponsesClient::ConfigurationError => e
      Rails.logger.error(ai_comment_error_log(diagnosis_id, e, category: "configuration"))
      if Rails.env.development?
        Rails.logger.info("[GenerateAiCommentJob] Using development fallback ai comment: diagnosis_id=#{diagnosis_id}")
        diagnosis&.update!(
          ai_comment: development_fallback_comment(diagnosis),
          ai_comment_status: :ai_comment_completed,
          ai_comment_failure_reason: nil,
          ai_commented_at: Time.current
        )
      else
        record_failure(diagnosis, e, category: "configuration")
      end
    rescue OpenAiResponsesClient::TimeoutError => e
      Rails.logger.error(ai_comment_error_log(diagnosis_id, e, category: "timeout"))
      record_failure(diagnosis, e, category: "timeout")
    rescue OpenAiResponsesClient::ResponseFormatError => e
      Rails.logger.error(ai_comment_error_log(diagnosis_id, e, category: "response_format"))
      record_failure(diagnosis, e, category: "response_format")
    rescue OpenAiResponsesClient::RequestError => e
      Rails.logger.error(ai_comment_error_log(diagnosis_id, e, category: "request"))
      record_failure(diagnosis, e, category: "request")
    rescue StandardError => e
      Rails.logger.error(ai_comment_error_log(diagnosis_id, e, category: "unexpected"))
      record_failure(diagnosis, e, category: "unexpected")
    end

    private

    def ai_comment_error_log(diagnosis_id, error, category:)
      "[GenerateAiCommentJob] Failed: diagnosis_id=#{diagnosis_id} category=#{category} error=#{error.class}: #{error.message}"
    end

    def record_failure(diagnosis, error, category:)
      return if diagnosis.blank?

      diagnosis.update!(
        ai_comment_status: :ai_comment_failed,
        ai_comment_failure_reason: failure_reason(error, category),
        result_payload: result_payload_with_ai_comment_debug(diagnosis, error, category)
      )
    end

    def failure_reason(error, category)
      "ai_comment_#{category}: #{error.class}: #{error.message}".truncate(500)
    end

    def result_payload_with_ai_comment_debug(diagnosis, error, category)
      payload = diagnosis.result_payload.is_a?(Hash) ? diagnosis.result_payload.deep_dup : {}
      payload["ai_comment_debug"] = {
        "status" => "failed",
        "category" => category,
        "error_class" => error.class.name,
        "message" => error.message.to_s.truncate(500),
        "failed_at" => Time.current.iso8601,
        "rails_env" => Rails.env.to_s,
        "queue_adapter" => ActiveJob::Base.queue_adapter.class.name
      }
      payload
    end

    def development_fallback_comment(diagnosis)
      scores = {
        "音程" => normalized_score(diagnosis&.pitch_score),
        "リズム" => normalized_score(diagnosis&.rhythm_score),
        "表現" => normalized_score(diagnosis&.expression_score)
      }
      scored_items = scores.select { |_label, score| score.present? }
      strongest_label, strongest_score = scored_items.max_by { |_label, score| score.to_i }
      focus_label, focus_score = scored_items.min_by { |_label, score| score.to_i }

      strongest_label ||= "全体のまとまり"
      focus_label ||= "基礎の安定感"
      overall = normalized_score(diagnosis&.overall_score)
      performance_label = diagnosis&.performance_type_label.presence || "今回の診断"

      [
        "今回の#{performance_label}では、#{strength_sentence(strongest_label, strongest_score, overall)}",
        "#{focus_sentence(focus_label, focus_score)}",
        "#{practice_sentence(focus_label, diagnosis)}"
      ].join
    end

    def normalized_score(value)
      return nil if value.blank?

      Integer(value).clamp(0, 100)
    rescue ArgumentError, TypeError
      nil
    end

    def strength_sentence(label, score, overall)
      if score.to_i >= 80
        "#{label}に強みが見られます。スコア全体も安定しており、今の良さを練習の軸にしやすい状態です。"
      elsif score.to_i >= 65
        "#{label}に土台ができています。大きく崩れにくい部分があるので、そこを活かすと演奏全体を整えやすくなります。"
      elsif overall.to_i >= 70
        "全体としてまとまりが見えています。特に#{label}を少しずつ安定させることで、次の伸びが作りやすくなります。"
      else
        "伸ばせるポイントがはっきり見えています。まずは短い範囲で確認しながら、安定する感覚を積み上げていきましょう。"
      end
    end

    def focus_sentence(label, score)
      if score.to_i >= 75
        "一方で、#{label}はさらに磨く余地があります。良い状態だからこそ、細かな揺れや入り方を整えると印象がよりクリアになります。"
      elsif score.to_i >= 55
        "一方で、#{label}はもう一段安定させられそうです。焦って大きく変えるより、録音を聴きながら少しずつ整えるのがおすすめです。"
      else
        "一方で、#{label}は今回の伸ばしどころです。短いフレーズに絞って反復すると、変化を確認しやすくなります。"
      end
    end

    def practice_sentence(label, diagnosis)
      case label
      when "音程"
        "次回は出だしと語尾の音を録音で確認し、狙った高さに無理なく戻れる感覚を探してみましょう。"
      when "リズム"
        "次回はメトロノームや原曲に合わせて、歌い出しやフレーズの入りのタイミングを意識して練習してみましょう。"
      when "表現"
        "次回は強く伝えたい一行を決め、声量や語尾のニュアンスを少し変えて録音で聴き比べてみましょう。"
      else
        if diagnosis&.performance_type_band?
          "次回は8小節ほどに絞って録音し、音量バランスと入りのタイミングを全員で確認してみましょう。"
        else
          "次回は一番気になる短い範囲を選び、ゆっくり録音してから少しずつテンポを戻してみましょう。"
        end
      end
    end
  end
end
