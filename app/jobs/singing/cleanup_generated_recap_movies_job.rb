module Singing
  class CleanupGeneratedRecapMoviesJob < ApplicationJob
    queue_as :default

    def perform
      targets = SingingGeneratedRecapMovie.expired_targets

      targets.find_each do |movie|
        movie.expire!
        Rails.logger.info("[RecapMovieCleanup] expired movie_id=#{movie.id} year=#{movie.year} customer_id=#{movie.customer_id}")
      rescue StandardError => e
        Rails.logger.error("[RecapMovieCleanup] failed movie_id=#{movie.id}: #{e.message}")
      end
    end
  end
end
