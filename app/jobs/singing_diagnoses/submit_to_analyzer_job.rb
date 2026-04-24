module SingingDiagnoses
  class SubmitToAnalyzerJob < ApplicationJob
    queue_as :default

    def perform(diagnosis_id)
      Rails.logger.info("Singing analyzer job started: diagnosis_id=#{diagnosis_id}") if defined?(Rails)

      diagnosis = SingingDiagnosis.find_by(id: diagnosis_id)
      if diagnosis.blank?
        Rails.logger.warn("Singing analyzer job skipped: diagnosis_id=#{diagnosis_id} not found") if defined?(Rails)
        return
      end

      SingingDiagnoses::SubmitToAnalyzer.call(diagnosis)
    end
  end
end
