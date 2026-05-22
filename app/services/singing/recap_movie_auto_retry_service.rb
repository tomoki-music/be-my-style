module Singing
  class RecapMovieAutoRetryService
    MAX_PER_RUN = 20

    Result = Struct.new(
      :processed_count,
      :succeeded_count,
      :skipped_count,
      :failed_count,
      keyword_init: true
    )

    def self.call
      new.call
    end

    def call
      processed = succeeded = skipped = failed = 0

      due_failures.each do |failure|
        processed += 1
        case attempt_retry(failure)
        when :succeeded then succeeded += 1
        when :skipped   then skipped   += 1
        when :failed    then failed    += 1
        end
      end

      Result.new(
        processed_count: processed,
        succeeded_count: succeeded,
        skipped_count:   skipped,
        failed_count:    failed
      )
    end

    private

    def due_failures
      SingingRecapMovieBatchFailure.auto_retry_due.order(next_auto_retry_at: :asc).limit(MAX_PER_RUN)
    end

    # active batch が動いている場合は inner service に渡すと :skipped に永続遷移してしまうため
    # ここで先回りして reschedule する
    def attempt_retry(failure)
      if SingingRecapMovieBatchExecution.active_for_year(failure.year).exists?
        Rails.logger.info(
          "[RecapMovieAutoRetryService] deferred: active batch year=#{failure.year} failure_id=#{failure.id}"
        )
        reschedule_or_exhaust(failure, failure.auto_retry_attempts_count,
                              "Active batch running for year #{failure.year}")
        return :skipped
      end

      new_count = failure.auto_retry_attempts_count + 1
      failure.update!(
        auto_retry_status:         :running,
        auto_retry_attempts_count: new_count,
        last_auto_retry_at:        Time.current
      )

      result = Singing::RecapMovieFailureRetryService.call(failure: failure, admin: nil)

      if result.success?
        Rails.logger.info(
          "[RecapMovieAutoRetryService] enqueued failure_id=#{failure.id} attempt=#{new_count}"
        )
        :succeeded
      else
        failure.reload
        if failure.retry_skipped?
          # Movie がすでに completed だった場合 — auto retry 不要
          failure.update!(auto_retry_status: :not_applicable)
          Rails.logger.info(
            "[RecapMovieAutoRetryService] skipped (movie already done) failure_id=#{failure.id}"
          )
          :skipped
        else
          Rails.logger.warn(
            "[RecapMovieAutoRetryService] service refused failure_id=#{failure.id}: #{result.message}"
          )
          reschedule_or_exhaust(failure, new_count, result.message.to_s)
          :failed
        end
      end
    rescue => e
      Rails.logger.error(
        "[RecapMovieAutoRetryService] error failure_id=#{failure.id}: #{e.message}"
      )
      begin
        reschedule_or_exhaust(failure, failure.auto_retry_attempts_count, e.message.to_s.truncate(1000))
      rescue => inner
        Rails.logger.error(
          "[RecapMovieAutoRetryService] failed to update failure after error: #{inner.message}"
        )
      end
      :failed
    end

    def reschedule_or_exhaust(failure, current_count, message)
      if current_count >= SingingRecapMovieBatchFailure::AUTO_RETRY_MAX_ATTEMPTS
        failure.update!(
          auto_retry_status:        :exhausted,
          auto_retry_error_message: message.to_s.truncate(1000)
        )
        Rails.logger.info(
          "[RecapMovieAutoRetryService] exhausted failure_id=#{failure.id} attempts=#{current_count}"
        )
      else
        next_at = Singing::RecapMovieAutoRetryPolicy.next_retry_at(current_count)
        failure.update!(
          auto_retry_status:        :scheduled,
          next_auto_retry_at:       next_at,
          auto_retry_error_message: message.to_s.truncate(1000)
        )
        Rails.logger.info(
          "[RecapMovieAutoRetryService] rescheduled failure_id=#{failure.id} next_at=#{next_at}"
        )
      end
    end
  end
end
