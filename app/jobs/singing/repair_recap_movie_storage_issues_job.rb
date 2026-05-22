module Singing
  class RepairRecapMovieStorageIssuesJob < ApplicationJob
    queue_as :default

    BATCH_LIMIT = 50

    def perform(dry_run: true)
      audit = Singing::RecapMovieStorageAuditService.call

      unless audit[:has_anomalies]
        Rails.logger.info("[RecapMovieRepair] No anomalies detected. Nothing to repair.")
        return build_no_op_result
      end

      Rails.logger.info(
        "[RecapMovieRepair] Anomalies detected — " \
        "completed_without_file=#{audit[:completed_without_file_count]} " \
        "cleaned_but_attached=#{audit[:cleaned_but_attached_count]} " \
        "dry_run=#{dry_run}"
      )

      Singing::RecapMovieStorageRepairService.call(dry_run: dry_run, limit: BATCH_LIMIT)
    end

    private

    def build_no_op_result
      Singing::RecapMovieStorageRepairService::Result.new(
        repaired_cba_count: 0,
        repaired_cwf_count: 0,
        dry_run:            true,
      )
    end
  end
end
