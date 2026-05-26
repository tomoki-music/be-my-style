module Singing
  class RecapMovieFailureRetryService
    Result = Struct.new(:success?, :message, :movie, keyword_init: true)

    def self.call(failure:, admin:)
      new(failure: failure, admin: admin).call
    end

    def initialize(failure:, admin:)
      @failure = failure
      @admin   = admin
    end

    def call
      guard_result = check_preconditions
      return guard_result if guard_result

      movie = find_movie

      if movie&.completed? && !movie&.expired?
        return skip_result("Recap Movie は completed のため再実行不要です")
      end

      movie = ensure_movie_ready(movie)
      mark_retried!(movie)

      Rails.logger.info("[RecapMovieRetry] reset movie_id=#{movie.id} to pending")
      Result.new(success?: true, message: "runner待ちに戻しました", movie: movie)
    rescue => e
      mark_retry_failed!(e.message.to_s.truncate(1000))
      Result.new(success?: false, message: "再実行中にエラーが発生しました: #{e.message.truncate(100)}", movie: nil)
    end

    private

    def check_preconditions
      unless @failure.retryable?
        return Result.new(success?: false, message: "このfailureはすでにretry済み・スキップ済みです", movie: nil)
      end

      if active_batch_exists?
        mark_skipped!("同一年のbatch実行中のためskip")
        return Result.new(success?: false, message: "#{@failure.year}年の Batch が実行中のため再実行できません", movie: nil)
      end

      nil
    end

    def active_batch_exists?
      SingingRecapMovieBatchExecution.active_for_year(@failure.year).exists?
    end

    # customer_id + year のユニーク制約があるため、こちらで確実に検索
    def find_movie
      SingingGeneratedRecapMovie.find_by(
        customer_id: @failure.customer_id,
        year:        @failure.year
      )
    end

    def ensure_movie_ready(movie)
      if movie
        movie.update!(status: :pending, error_message: nil)
        movie
      else
        new_movie = SingingGeneratedRecapMovie.create!(
          customer_id: @failure.customer_id,
          year:        @failure.year,
          status:      :pending
        )
        @failure.update!(recap_movie_id: new_movie.id)
        new_movie
      end
    end

    def mark_retried!(movie)
      @failure.update!(
        retry_status:  :retried,
        retried_at:    Time.current,
        retried_by_id: @admin&.id
      )
    end

    def skip_result(reason)
      mark_skipped!(reason)
      Result.new(success?: false, message: reason, movie: nil)
    end

    def mark_skipped!(reason)
      @failure.update!(
        retry_status:        :skipped,
        retry_error_message: reason.to_s.truncate(1000)
      )
    end

    def mark_retry_failed!(message)
      @failure.update!(
        retry_status:        :retry_failed,
        retry_error_message: message
      )
    end
  end
end
