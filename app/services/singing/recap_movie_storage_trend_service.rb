module Singing
  class RecapMovieStorageTrendService
    BYTES_PER_GB = Singing::RecapMovieStorageMetricsService::BYTES_PER_GB

    def self.call(days: 30)
      new(days: days).call
    end

    def initialize(days: 30)
      @days = days
    end

    def call
      snapshots = SingingRecapMovieStorageSnapshot.ascending.recent(@days).to_a

      {
        days:               @days,
        snapshot_count:     snapshots.size,
        snapshots:          build_snapshot_series(snapshots),
        storage_growth:     build_storage_growth(snapshots),
        cost_trend:         build_cost_trend(snapshots),
        cleanup_effect:     build_cleanup_effect(snapshots),
        has_data:           snapshots.size >= 2,
        oldest_snapshot_at: snapshots.first&.snapshot_date,
        latest_snapshot_at: snapshots.last&.snapshot_date,
      }
    end

    private

    def build_snapshot_series(snapshots)
      snapshots.map do |s|
        {
          date:                      s.snapshot_date,
          attached_movie_count:      s.attached_movie_count,
          total_bytes:               s.total_bytes,
          total_gb:                  s.total_gb.round(3),
          completed_bytes:           s.completed_bytes,
          expired_attached_bytes:    s.expired_attached_bytes,
          estimated_monthly_cost_usd: s.estimated_monthly_cost_usd.to_f,
        }
      end
    end

    def build_storage_growth(snapshots)
      return empty_growth if snapshots.size < 2

      first = snapshots.first
      last  = snapshots.last
      delta_bytes = last.total_bytes - first.total_bytes
      delta_gb    = delta_bytes.to_f / BYTES_PER_GB
      days_diff   = [(last.snapshot_date - first.snapshot_date).to_i, 1].max

      {
        delta_bytes:         delta_bytes,
        delta_gb:            delta_gb.round(3),
        daily_avg_bytes:     (delta_bytes.to_f / days_diff).round,
        daily_avg_gb:        (delta_gb / days_diff).round(4),
        growth_pct:          first.total_bytes > 0 ? (delta_bytes.to_f / first.total_bytes * 100).round(1) : nil,
        first_total_bytes:   first.total_bytes,
        last_total_bytes:    last.total_bytes,
        period_days:         days_diff,
      }
    end

    def build_cost_trend(snapshots)
      return { delta_usd: nil, first_usd: nil, last_usd: nil } if snapshots.size < 2

      first_cost = snapshots.first.estimated_monthly_cost_usd.to_f
      last_cost  = snapshots.last.estimated_monthly_cost_usd.to_f

      {
        first_usd: first_cost.round(4),
        last_usd:  last_cost.round(4),
        delta_usd: (last_cost - first_cost).round(4),
      }
    end

    def build_cleanup_effect(snapshots)
      # expired_attached_bytes の期間内での最大値 vs 最小値で cleanup 効果を可視化
      return { max_expired_bytes: 0, min_expired_bytes: 0, reduced_bytes: 0 } if snapshots.empty?

      expired_series = snapshots.map(&:expired_attached_bytes)
      max_val = expired_series.max
      min_val = expired_series.min

      {
        max_expired_bytes: max_val,
        min_expired_bytes: min_val,
        reduced_bytes:     [max_val - min_val, 0].max,
      }
    end

    def empty_growth
      {
        delta_bytes:        0,
        delta_gb:           0.0,
        daily_avg_bytes:    0,
        daily_avg_gb:       0.0,
        growth_pct:         nil,
        first_total_bytes:  0,
        last_total_bytes:   0,
        period_days:        0,
      }
    end
  end
end
