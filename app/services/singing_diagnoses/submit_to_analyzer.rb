module SingingDiagnoses
  class SubmitToAnalyzer
    GENERIC_FAILURE_MESSAGE = "診断処理に一時的に失敗しました。時間をおいて再度お試しください。".freeze

    def self.call(diagnosis, client: AnalyzerClient.new)
      new(diagnosis, client: client).call
    end

    def initialize(diagnosis, client:)
      @diagnosis = diagnosis
      @client = client
    end

    def call
      return false unless diagnosis.queued?

      Rails.logger.info("Singing diagnosis submission started: diagnosis_id=#{diagnosis.id}") if defined?(Rails)

      diagnosis.update!(status: :processing, failure_reason: nil)
      payload = client.submit(diagnosis)
      ResultPersister.call(diagnosis, payload).tap do |result|
        Rails.logger.info("Singing diagnosis submission completed: diagnosis_id=#{diagnosis.id}") if result && defined?(Rails)
      end
    rescue AnalyzerClient::ConnectionError, AnalyzerClient::TimeoutError => e
      Rails.logger.error("Singing diagnosis connection/timeout error: diagnosis_id=#{diagnosis&.id} error=#{e.class}: #{e.message}") if defined?(Rails)
      mark_failed(e.message)
    rescue AnalyzerClient::RequestError, AnalyzerClient::ConfigurationError => e
      Rails.logger.error("Singing diagnosis request error: diagnosis_id=#{diagnosis&.id} error=#{e.class}: #{e.message}") if defined?(Rails)
      mark_failed(e.message)
    rescue StandardError => e
      Rails.logger.error("Singing diagnosis unexpected error: diagnosis_id=#{diagnosis&.id} error=#{e.class}: #{e.message}") if defined?(Rails)
      mark_failed(GENERIC_FAILURE_MESSAGE)
    end

    private

    attr_reader :diagnosis, :client

    def mark_failed(reason)
      diagnosis.update!(status: :failed, failure_reason: reason) if diagnosis&.persisted?
      false
    end
  end
end
