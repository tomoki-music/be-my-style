module Singing
  class RecapMovieStorageAuditService
    AUDIT_RECORD_LIMIT = 50

    def self.call
      new.call
    end

    def call
      cwf = completed_without_file
      cba = cleaned_but_attached

      {
        completed_without_file_count: cwf.count,
        cleaned_but_attached_count:   cba.count,
        completed_without_file:       cwf.includes(:customer).limit(AUDIT_RECORD_LIMIT),
        cleaned_but_attached:         cba.includes(:customer).limit(AUDIT_RECORD_LIMIT),
        has_anomalies:                cwf.exists? || cba.exists?,
        audited_at:                   Time.current,
      }
    end

    private

    # status = completed だが video_file が attach されていない (S3 消失 / purge 競合)
    def completed_without_file
      SingingGeneratedRecapMovie
        .completed
        .left_joins(:video_file_attachment)
        .where(active_storage_attachments: { id: nil })
    end

    # status = expired かつ cleaned_up_at が記録済みなのに video_file がまだ存在する
    # (purge_later が失敗 / 遅延している可能性)
    def cleaned_but_attached
      SingingGeneratedRecapMovie
        .expired
        .where.not(cleaned_up_at: nil)
        .joins(:video_file_attachment)
    end
  end
end
