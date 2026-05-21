module Singing
  class RecapMovieRetryReconciliationService
    def self.call(movie)
      new(movie).call
    end

    def initialize(movie)
      @movie = movie
    end

    def call
      failures = SingingRecapMovieBatchFailure
        .where(customer_id: @movie.customer_id, year: @movie.year)
        .retry_retried

      return if failures.empty?

      if @movie.completed?
        resolve_failures!(failures)
        Rails.logger.info(
          "[RecapMovieRetryReconciliationService] resolved #{failures.count} failure(s) " \
          "customer_id=#{@movie.customer_id} year=#{@movie.year} movie_id=#{@movie.id}"
        )
      elsif @movie.failed?
        mark_retry_failed!(failures)
        Rails.logger.info(
          "[RecapMovieRetryReconciliationService] retry_failed #{failures.count} failure(s) " \
          "customer_id=#{@movie.customer_id} year=#{@movie.year} movie_id=#{@movie.id} " \
          "error=#{@movie.error_message.to_s.truncate(200)}"
        )
      end
    end

    private

    def resolve_failures!(failures)
      failures.update_all(
        retry_status:      "resolved",
        resolved_at:       Time.current,
        resolved_movie_id: @movie.id,
        updated_at:        Time.current
      )
    end

    def mark_retry_failed!(failures)
      failures.update_all(
        retry_status:        "retry_failed",
        retry_error_message: @movie.error_message.to_s.truncate(1000),
        updated_at:          Time.current
      )
    end
  end
end
