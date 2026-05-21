module Singing
  class GenerateYearlyRecapMoviesJob < ApplicationJob
    queue_as :default

    def perform(year, execution_id = nil)
      execution = find_execution(execution_id, year)
      execution&.update!(status: :running)

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

      enqueued_count = 0
      skipped_count = 0

      customers.find_each do |customer|
        movie = find_or_prepare_movie!(customer, year)

        if movie
          Singing::GenerateRecapMovieJob.perform_later(movie.id)
          enqueued_count += 1
        else
          skipped_count += 1
        end
      rescue StandardError => e
        Rails.logger.error("[RecapMovieBatch] error customer_id=#{customer.id} year=#{year}: #{e.message}")
        skipped_count += 1
      end

      Rails.logger.info("[RecapMovieBatch] year=#{year} enqueued=#{enqueued_count} skipped=#{skipped_count}")
      execution&.update!(status: :completed)
    rescue StandardError => e
      execution&.update!(status: :failed) rescue nil
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
        return nil unless existing.failed? || existing.expired?

        existing.update!(status: :pending, error_message: nil)
        return existing
      end

      SingingGeneratedRecapMovie.create!(
        customer: customer,
        year: year,
        status: :pending,
        expires_at: 30.days.from_now
      )
    end
  end
end
