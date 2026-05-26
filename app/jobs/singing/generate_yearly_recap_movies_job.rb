module Singing
  class GenerateYearlyRecapMoviesJob < ApplicationJob
    queue_as :default

    def perform(year, execution_id = nil)
      execution = find_execution(execution_id, year)

      year_range = Time.zone.local(year, 1, 1).all_year

      customers = Customer
        .joins(:domains, :singing_diagnoses)
        .where(is_deleted: false)
        .where(domains: { name: "singing" })
        .where(singing_diagnoses: {
          status: SingingDiagnosis.statuses[:completed],
          created_at: year_range
        })
        .distinct

      enqueue_targets = customers.to_a

      execution&.update!(
        status:              :running,
        started_at:          Time.current,
        total_movies_count:  enqueue_targets.size,
      )

      pending_count     = 0
      skipped_count     = 0
      created_count     = 0
      regenerated_count = 0
      actual_skipped_count = 0

      enqueue_targets.each do |customer|
        movie = nil
        movie, action = find_or_prepare_movie!(customer, year)

        if movie
          Rails.logger.info("[RecapMovieBatch] queued movie_id=#{movie.id} as pending")
          execution&.increment!(:completed_movies_count)
          pending_count += 1
          case action
          when :created     then created_count += 1
          when :regenerated then regenerated_count += 1
          end
        else
          skipped_count += 1
          actual_skipped_count += 1
        end
      rescue StandardError => e
        Rails.logger.error("[RecapMovieBatch] error customer_id=#{customer.id} year=#{year}: #{e.message}")
        execution&.increment!(:failed_movies_count)
        if execution
          failure = execution.failures.create!(
            customer:          customer,
            year:              year,
            recap_movie_id:    movie&.id,
            error_class:       e.class.name,
            error_message:     e.message.to_s.truncate(1000),
            backtrace_excerpt: e.backtrace&.first(5)&.join("\n"),
            failed_at:         Time.current,
          )
          Singing::RecapMovieAutoRetryPolicy.schedule_auto_retry_if_eligible!(failure)
        end
        skipped_count += 1
      end

      Rails.logger.info("[RecapMovieBatch] year=#{year} pending=#{pending_count} skipped=#{skipped_count} (created=#{created_count} regenerated=#{regenerated_count} actual_skipped=#{actual_skipped_count})")
      execution&.update!(
        status:                          :completed,
        finished_at:                     Time.current,
        actual_created_movies_count:     created_count,
        actual_regenerated_movies_count: regenerated_count,
        actual_skipped_movies_count:     actual_skipped_count,
      )
    rescue StandardError => e
      execution&.update!(status: :failed, finished_at: Time.current) rescue nil
      raise
    end

    private

    def find_execution(execution_id, year)
      return SingingRecapMovieBatchExecution.find(execution_id) if execution_id.present?

      SingingRecapMovieBatchExecution
        .where(year: year, status: :enqueued)
        .order(created_at: :desc)
        .first
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def find_or_prepare_movie!(customer, year)
      existing = SingingGeneratedRecapMovie.find_by(customer: customer, year: year)

      if existing
        return [nil, :skipped] unless existing.failed? || existing.expired?

        existing.update!(status: :pending, error_message: nil)
        return [existing, :regenerated]
      end

      movie = SingingGeneratedRecapMovie.create!(
        customer: customer,
        year: year,
        status: :pending,
        expires_at: 30.days.from_now
      )
      [movie, :created]
    end
  end
end
