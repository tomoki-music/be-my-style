module Singing
  class AwardAchievementBadgesJob < ApplicationJob
    queue_as :default

    def perform(diagnosis_id)
      diagnosis = SingingDiagnosis.find_by(id: diagnosis_id)

      unless diagnosis
        Rails.logger.warn("[Singing::AwardAchievementBadgesJob] diagnosis not found: #{diagnosis_id}")
        return
      end

      return unless diagnosis.completed?

      Singing::AwardAchievementBadgesService.call(diagnosis)
    end
  end
end
