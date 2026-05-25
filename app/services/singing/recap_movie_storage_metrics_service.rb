module Singing
  class RecapMovieStorageMetricsService
    # AWS S3 標準ストレージ 概算単価 (USD/GB/月)
    # 転送料・リクエスト料金は含まない
    S3_PRICE_PER_GB_USD = 0.025
    BYTES_PER_GB        = 1_073_741_824.0 # 1024^3
    RECENT_DAYS         = 30

    PLAN_ORDER = %w[premium core light free].freeze

    def self.call
      new.call
    end

    def call
      {
        attached_movie_count:   attached_movie_count,
        total_bytes:            total_bytes,
        avg_bytes:              avg_bytes,
        completed_bytes:        completed_bytes,
        expired_attached_bytes: expired_attached_bytes,
        recent_bytes:           recent_bytes,
        cost_estimation:        build_cost_estimation,
        year_breakdown:         build_year_breakdown,
        plan_breakdown:         build_plan_breakdown,
        collected_at:           Time.current,
      }
    end

    private

    def blob_join_scope
      @blob_join_scope ||= SingingGeneratedRecapMovie.joins(
        "INNER JOIN active_storage_attachments asa" \
        "  ON asa.record_type = 'SingingGeneratedRecapMovie'" \
        "  AND asa.name = 'video_file'" \
        "  AND asa.record_id = singing_generated_recap_movies.id" \
        " INNER JOIN active_storage_blobs asb ON asb.id = asa.blob_id"
      )
    end

    def attached_movie_count
      @attached_movie_count ||= blob_join_scope.count
    end

    def total_bytes
      @total_bytes ||= blob_join_scope.sum("asb.byte_size")
    end

    def avg_bytes
      attached_movie_count > 0 ? (total_bytes.to_f / attached_movie_count).round : 0
    end

    def completed_bytes
      blob_join_scope.completed.sum("asb.byte_size")
    end

    def expired_attached_bytes
      blob_join_scope.expired.sum("asb.byte_size")
    end

    def recent_bytes
      blob_join_scope
        .where("singing_generated_recap_movies.generated_at >= ?", RECENT_DAYS.days.ago)
        .sum("asb.byte_size")
    end

    def build_cost_estimation
      total_gb         = total_bytes.to_f / BYTES_PER_GB
      monthly_cost_usd = (total_gb * S3_PRICE_PER_GB_USD).round(4)

      {
        total_gb:         total_gb.round(3),
        monthly_cost_usd: monthly_cost_usd,
        price_per_gb_usd: S3_PRICE_PER_GB_USD,
        note:             "概算（転送料・リクエスト料金は含まない）",
      }
    end

    def build_year_breakdown
      blob_join_scope
        .group("singing_generated_recap_movies.year")
        .order("singing_generated_recap_movies.year DESC")
        .select(
          "singing_generated_recap_movies.year AS year",
          "COUNT(*) AS movie_count",
          "SUM(asb.byte_size) AS total_bytes",
        )
        .map { |r| { year: r.year, count: r.movie_count, bytes: r.total_bytes.to_i } }
    end

    def build_plan_breakdown
      blob_join_scope
        .joins(
          "LEFT JOIN subscriptions s" \
          "  ON s.customer_id = singing_generated_recap_movies.customer_id"
        )
        .group("COALESCE(s.plan, 'free')")
        .select(
          "COALESCE(s.plan, 'free') AS plan_name",
          "COUNT(*) AS movie_count",
          "SUM(asb.byte_size) AS total_bytes",
        )
        .map { |r| { plan: r.plan_name.presence || "free", count: r.movie_count, bytes: r.total_bytes.to_i } }
        .sort_by { |row| PLAN_ORDER.index(row[:plan]) || PLAN_ORDER.size }
    end
  end
end
