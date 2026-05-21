module Singing
  class RecapMovieBatchPreviewService
    def self.call(year)
      new(year).call
    end

    def initialize(year)
      @year = year
    end

    def call
      customer_ids = target_customer_ids

      existing_movies = SingingGeneratedRecapMovie
        .where(customer_id: customer_ids, year: @year)
        .index_by(&:customer_id)

      new_count        = 0
      regenerate_count = 0
      skipped_count    = 0
      skipped_breakdown = { pending: 0, processing: 0, completed: 0 }

      customer_ids.each do |customer_id|
        movie = existing_movies[customer_id]

        if movie.nil?
          new_count += 1
        elsif movie.failed? || movie.expired?
          regenerate_count += 1
        else
          skipped_count += 1
          key = movie.status.to_sym
          skipped_breakdown[key] = (skipped_breakdown[key] || 0) + 1
        end
      end

      {
        year:                    @year,
        target_customers_count:  customer_ids.length,
        new_movies_count:        new_count,
        regenerate_movies_count: regenerate_count,
        skipped_movies_count:    skipped_count,
        skipped_breakdown:       skipped_breakdown,
      }
    end

    private

    def target_customer_ids
      year_range = Time.zone.local(@year, 1, 1).all_year

      Customer
        .joins(:domains, :singing_diagnoses)
        .where(is_deleted: false)
        .where(domains: { name: "singing" })
        .where(singing_diagnoses: {
          status:     SingingDiagnosis.statuses[:completed],
          created_at: year_range,
        })
        .distinct
        .pluck(:id)
    end
  end
end
