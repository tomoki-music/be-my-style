module SingingDiagnoses
  class SubmitToAnalyzer
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
    rescue StandardError => e
      failure_reason = "#{e.class}: #{e.message}"
      Rails.logger.warn("Singing diagnosis analyzer submission failed: diagnosis_id=#{diagnosis&.id} reason=#{failure_reason}") if defined?(Rails)
      diagnosis.update!(status: :failed, failure_reason: failure_reason) if diagnosis&.persisted?
      false
    end

    private

    attr_reader :diagnosis, :client
  end
end
