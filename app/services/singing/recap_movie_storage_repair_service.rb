module Singing
  class RecapMovieStorageRepairService
    REPAIR_BATCH_LIMIT = 50

    Result = Struct.new(
      :repaired_cba_count,
      :repaired_cwf_count,
      :dry_run,
      keyword_init: true,
    )

    def self.call(dry_run: true, limit: REPAIR_BATCH_LIMIT)
      new(dry_run: dry_run, limit: limit).call
    end

    def initialize(dry_run: true, limit: REPAIR_BATCH_LIMIT)
      @dry_run = dry_run
      @limit   = limit
    end

    def call
      Rails.logger.info("[RecapMovieRepair] Start — dry_run=#{@dry_run} limit=#{@limit}")

      cba = repair_cleaned_but_attached
      cwf = repair_completed_without_file

      Rails.logger.info(
        "[RecapMovieRepair] Done — " \
        "repaired_cba=#{cba} repaired_cwf=#{cwf} dry_run=#{@dry_run}"
      )

      Result.new(repaired_cba_count: cba, repaired_cwf_count: cwf, dry_run: @dry_run)
    end

    private

    # cleaned_but_attached:
    #   status=expired + cleaned_up_at あり + attachment 残存
    #   → purge_later 再実行 (S3 直接操作・blob 直接 delete は禁止)
    def repair_cleaned_but_attached
      scope = SingingGeneratedRecapMovie
        .expired
        .where.not(cleaned_up_at: nil)
        .joins(:video_file_attachment)
        .limit(@limit)

      count = 0
      scope.find_each do |movie|
        if @dry_run
          Rails.logger.info(
            "[RecapMovieRepair] [DRY_RUN] cleaned_but_attached: " \
            "would purge_later movie_id=#{movie.id} customer_id=#{movie.customer_id}"
          )
        else
          movie.video_file.purge_later
          Rails.logger.info(
            "[RecapMovieRepair] cleaned_but_attached: " \
            "purge_later enqueued movie_id=#{movie.id} customer_id=#{movie.customer_id}"
          )
        end
        count += 1
      rescue StandardError => e
        Rails.logger.error(
          "[RecapMovieRepair] cleaned_but_attached: " \
          "error movie_id=#{movie.id} #{e.class}: #{e.message}"
        )
      end
      count
    end

    # completed_without_file:
    #   status=completed + video_file なし (S3 消失 / purge 競合)
    #   → mark_failed! で安全側に倒す。自動再生成・blob 削除はしない。
    def repair_completed_without_file
      scope = SingingGeneratedRecapMovie
        .completed
        .left_joins(:video_file_attachment)
        .where(active_storage_attachments: { id: nil })
        .limit(@limit)

      count = 0
      scope.find_each do |movie|
        if @dry_run
          Rails.logger.info(
            "[RecapMovieRepair] [DRY_RUN] completed_without_file: " \
            "would mark_failed! movie_id=#{movie.id} customer_id=#{movie.customer_id}"
          )
        else
          movie.mark_failed!("Storage Repair: video_file が存在しないため failed に変更 (自動修復)")
          Rails.logger.info(
            "[RecapMovieRepair] completed_without_file: " \
            "mark_failed! movie_id=#{movie.id} customer_id=#{movie.customer_id}"
          )
        end
        count += 1
      rescue StandardError => e
        Rails.logger.error(
          "[RecapMovieRepair] completed_without_file: " \
          "error movie_id=#{movie.id} #{e.class}: #{e.message}"
        )
      end
      count
    end
  end
end
