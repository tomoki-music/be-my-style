module Singing
  class RunRecapMovieAutoRetriesJob < ApplicationJob
    queue_as :default

    def perform
      result = Singing::RecapMovieAutoRetryService.call

      Rails.logger.info(
        "[RunRecapMovieAutoRetriesJob] done " \
        "processed=#{result.processed_count} " \
        "succeeded=#{result.succeeded_count} " \
        "skipped=#{result.skipped_count} " \
        "failed=#{result.failed_count}"
      )

      result
    end
  end
end
