module Singing
  class CleanupGeneratedRecapMoviesJob < ApplicationJob
    queue_as :default

    BATCH_LIMIT = 200

    def perform
      targets  = SingingGeneratedRecapMovie.expired_targets.limit(BATCH_LIMIT)
      total    = 0
      succeeded = 0
      failed_ids = []

      targets.find_each do |movie|
        movie.expire!
        succeeded += 1
        Rails.logger.info("[RecapMovieCleanup] expired movie_id=#{movie.id} year=#{movie.year} customer_id=#{movie.customer_id}")
      rescue StandardError => e
        failed_ids << movie.id
        Rails.logger.error("[RecapMovieCleanup] failed movie_id=#{movie.id}: #{e.message}")
      ensure
        total += 1
      end

      Rails.logger.info(
        "[RecapMovieCleanup] done — total=#{total} succeeded=#{succeeded} failed=#{failed_ids.size}" \
        "#{failed_ids.any? ? " failed_ids=#{failed_ids.inspect}" : ""}"
      )
    end
  end
end
