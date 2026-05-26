module Singing
  class RecapMovieStorageSnapshotService
    Result = Struct.new(:snapshot, :created, :skipped, keyword_init: true)

    def self.call(date: Date.current)
      new(date: date).call
    end

    def initialize(date: Date.current)
      @date = date
    end

    def call
      if SingingRecapMovieStorageSnapshot.exists?(snapshot_date: @date)
        Rails.logger.info "[RecapMovieStorageSnapshotService] skipped: snapshot already exists for #{@date}"
        existing = SingingRecapMovieStorageSnapshot.find_by(snapshot_date: @date)
        return Result.new(snapshot: existing, created: false, skipped: true)
      end

      metrics  = Singing::RecapMovieStorageMetricsService.call
      snapshot = SingingRecapMovieStorageSnapshot.create!(
        snapshot_date:             @date,
        attached_movie_count:      metrics[:attached_movie_count],
        total_bytes:               metrics[:total_bytes],
        avg_bytes:                 metrics[:avg_bytes],
        completed_bytes:           metrics[:completed_bytes],
        expired_attached_bytes:    metrics[:expired_attached_bytes],
        recent_bytes:              metrics[:recent_bytes],
        estimated_monthly_cost_usd: metrics[:cost_estimation][:monthly_cost_usd],
      )

      Rails.logger.info "[RecapMovieStorageSnapshotService] created snapshot for #{@date}: " \
                        "total_bytes=#{metrics[:total_bytes]} movies=#{metrics[:attached_movie_count]}"

      Result.new(snapshot: snapshot, created: true, skipped: false)
    end
  end
end
