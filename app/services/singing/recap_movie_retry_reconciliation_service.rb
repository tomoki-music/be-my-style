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
      failures.each do |failure|
        if failure.auto_retry_running? &&
           failure.auto_retry_attempts_count < SingingRecapMovieBatchFailure::AUTO_RETRY_MAX_ATTEMPTS
          # auto retry がまだ試行回数上限未満なら再スケジュール
          next_at = Singing::RecapMovieAutoRetryPolicy.next_retry_at(failure.auto_retry_attempts_count)
          failure.update!(
            retry_status:             :pending,
            auto_retry_status:        :scheduled,
            next_auto_retry_at:       next_at,
            auto_retry_error_message: @movie.error_message.to_s.truncate(1000)
          )
          Rails.logger.info(
            "[RecapMovieRetryReconciliationService] auto_retry rescheduled failure_id=#{failure.id} next_at=#{next_at}"
          )
        elsif failure.auto_retry_running?
          # 上限に達したので exhausted
          failure.update!(
            retry_status:        :retry_failed,
            auto_retry_status:   :exhausted,
            retry_error_message: @movie.error_message.to_s.truncate(1000)
          )
        else
          failure.update!(
            retry_status:        :retry_failed,
            retry_error_message: @movie.error_message.to_s.truncate(1000)
          )
        end
      end
    end
  end
end
