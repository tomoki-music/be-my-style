module Singing
  class RecapMovieHealthDashboardService
    TREND_DAYS            = 30
    OPEN_FAILURES_LIMIT   = 50
    SLOW_BATCHES_LIMIT    = 10
    ERROR_ANALYSIS_LIMIT  = 10
    AUTO_RETRY_FAILURES_LIMIT = 100

    VALID_AUTO_RETRY_FILTERS = %w[scheduled running exhausted due_now].freeze

    def self.call(auto_retry_filter: nil)
      new(auto_retry_filter: auto_retry_filter).call
    end

    def initialize(auto_retry_filter: nil)
      @auto_retry_filter = VALID_AUTO_RETRY_FILTERS.include?(auto_retry_filter) ? auto_retry_filter : nil
    end

    def call
      {
        summary:             build_summary,
        trends:              build_trends,
        error_analysis:      build_error_analysis,
        open_failures:       build_open_failures,
        slow_batches:        build_slow_batches,
        auto_retry_summary:  build_auto_retry_summary,
        auto_retry_failures: build_auto_retry_failures,
        storage_expiry:      build_storage_expiry,
      }
    end

    private

    def build_summary
      total     = SingingRecapMovieBatchExecution.count
      completed = SingingRecapMovieBatchExecution.completed.count

      batch_success_rate = total > 0 ? (completed.to_f / total * 100).round(1) : 0

      retry_attempted = SingingRecapMovieBatchFailure
        .where(retry_status: %w[retried resolved retry_failed])
        .count
      resolved_count = SingingRecapMovieBatchFailure.retry_resolved.count
      retry_recovery_rate = retry_attempted > 0 ? (resolved_count.to_f / retry_attempted * 100).round(1) : 0

      open_failures = SingingRecapMovieBatchFailure
        .where(retry_status: %w[pending retry_failed])
        .count

      durations = SingingRecapMovieBatchExecution
        .where.not(started_at: nil, finished_at: nil)
        .pluck(:started_at, :finished_at)
        .map { |s, f| (f - s).to_i }
        .select(&:positive?)
      avg_render_duration = durations.any? ? (durations.sum.to_f / durations.size).round.to_i : nil

      {
        total_batches:       total,
        batch_success_rate:  batch_success_rate,
        retry_recovery_rate: retry_recovery_rate,
        open_failures:       open_failures,
        avg_render_duration: avg_render_duration,
      }
    end

    def build_trends
      start_date = TREND_DAYS.days.ago.to_date

      executions_by_date = SingingRecapMovieBatchExecution
        .where("created_at >= ?", start_date.beginning_of_day)
        .group("DATE(created_at)")
        .select(
          "DATE(created_at) as date",
          "COUNT(*) as total_count",
          "SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count",
          "SUM(CASE WHEN status IN ('failed','cancelled') THEN 1 ELSE 0 END) as failed_count",
        )

      failures_by_date = SingingRecapMovieBatchFailure
        .where("failed_at >= ?", start_date.beginning_of_day)
        .group("DATE(failed_at)")
        .count

      resolved_by_date = SingingRecapMovieBatchFailure
        .retry_resolved
        .where("resolved_at >= ?", start_date.beginning_of_day)
        .group("DATE(resolved_at)")
        .count

      exec_map = executions_by_date.each_with_object({}) do |row, h|
        d = row.date.is_a?(String) ? Date.parse(row.date) : row.date.to_date
        h[d] = {
          total:     row.total_count.to_i,
          completed: row.completed_count.to_i,
          failed:    row.failed_count.to_i,
        }
      end

      (start_date..Time.zone.today).map do |date|
        ed = exec_map[date] || { total: 0, completed: 0, failed: 0 }
        failure_key  = date.to_s
        resolved_key = date.to_s
        {
          date:              date,
          total_batches:     ed[:total],
          completed_batches: ed[:completed],
          failed_batches:    ed[:failed],
          failure_count:     failures_by_date[failure_key].to_i,
          resolved_count:    resolved_by_date[resolved_key].to_i,
        }
      end
    end

    def build_error_analysis
      SingingRecapMovieBatchFailure
        .group(:error_class)
        .order("count_all DESC")
        .limit(ERROR_ANALYSIS_LIMIT)
        .count
    end

    def build_open_failures
      SingingRecapMovieBatchFailure
        .includes(:customer, :singing_recap_movie_batch_execution)
        .where(retry_status: %w[pending retry_failed])
        .order(failed_at: :desc)
        .limit(OPEN_FAILURES_LIMIT)
    end

    def build_slow_batches
      SingingRecapMovieBatchExecution
        .where.not(started_at: nil, finished_at: nil)
        .sort_by { |b| -(b.finished_at - b.started_at) }
        .first(SLOW_BATCHES_LIMIT)
    end

    def build_auto_retry_summary
      scheduled = SingingRecapMovieBatchFailure.auto_retry_scheduled.count
      running   = SingingRecapMovieBatchFailure.auto_retry_running.count
      exhausted = SingingRecapMovieBatchFailure.auto_retry_exhausted.count
      due_now   = SingingRecapMovieBatchFailure.auto_retry_due.count
      next_due  = SingingRecapMovieBatchFailure
        .auto_retry_scheduled
        .where("next_auto_retry_at > ?", Time.current)
        .minimum(:next_auto_retry_at)

      avg_attempts = SingingRecapMovieBatchFailure
        .where(auto_retry_status: %w[scheduled running exhausted])
        .average(:auto_retry_attempts_count)
        &.round(1)

      {
        scheduled:    scheduled,
        running:      running,
        exhausted:    exhausted,
        due_now:      due_now,
        next_due_at:  next_due,
        avg_attempts: avg_attempts,
      }
    end

    def build_storage_expiry
      cleanup_pending    = SingingGeneratedRecapMovie.cleanup_pending.count
      expired_total      = SingingGeneratedRecapMovie.expired.count
      recently_cleaned   = SingingGeneratedRecapMovie.recently_cleaned(7.days.ago).count
      expiring_soon      = SingingGeneratedRecapMovie
        .completed
        .where("expires_at BETWEEN ? AND ?", Time.current, 7.days.from_now)
        .count

      {
        cleanup_pending:  cleanup_pending,
        expired_total:    expired_total,
        recently_cleaned: recently_cleaned,
        expiring_soon:    expiring_soon,
      }
    end

    def build_auto_retry_failures
      scope = SingingRecapMovieBatchFailure
        .includes(:customer, :singing_recap_movie_batch_execution)
        .where.not(auto_retry_status: %w[not_applicable disabled])
        .order(failed_at: :desc)
        .limit(AUTO_RETRY_FAILURES_LIMIT)

      case @auto_retry_filter
      when "scheduled" then scope.auto_retry_scheduled
      when "running"   then scope.auto_retry_running
      when "exhausted" then scope.auto_retry_exhausted
      when "due_now"   then scope.auto_retry_due
      else scope
      end
    end
  end
end
