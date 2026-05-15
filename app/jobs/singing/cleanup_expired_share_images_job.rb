module Singing
  class CleanupExpiredShareImagesJob < ApplicationJob
    queue_as :default

    def perform
      stats = {
        target_count: cleanup_candidate_ids.size,
        purge_success_count: 0,
        destroy_count: 0,
        orphan_blob_purge_count: 0,
        error_count: 0
      }

      Rails.logger.info("[Singing::CleanupExpiredShareImagesJob] start #{stats.slice(:target_count).inspect}")

      cleanup_candidate_ids.each do |share_image_id|
        cleanup_share_image(share_image_id, stats)
      end

      cleanup_orphan_blobs(stats)

      Rails.logger.info("[Singing::CleanupExpiredShareImagesJob] finish #{stats.inspect}")
      stats
    end

    private

    def cleanup_candidate_ids
      @cleanup_candidate_ids ||= (
        SingingShareImage.expired_for_cleanup.pluck(:id) +
        SingingShareImage.failed_for_cleanup.pluck(:id) +
        SingingShareImage.missing_attachment_for_cleanup.pluck(:id)
      ).uniq
    end

    def cleanup_share_image(share_image_id, stats)
      share_image = SingingShareImage.find_by(id: share_image_id)
      return unless share_image&.cleanup_eligible?

      share_image.with_lock do
        return unless share_image.cleanup_eligible?

        if share_image.image.attached?
          share_image.image.purge
          stats[:purge_success_count] += 1
        end

        share_image.destroy!
        stats[:destroy_count] += 1
      end
    rescue StandardError => e
      stats[:error_count] += 1
      Rails.logger.error(
        "[Singing::CleanupExpiredShareImagesJob] cleanup failed " \
        "share_image_id=#{share_image_id} error=#{e.class.name}: #{e.message}"
      )
    end

    def cleanup_orphan_blobs(stats)
      ActiveStorage::Blob
        .left_outer_joins(:attachments)
        .where(active_storage_attachments: { id: nil })
        .where("active_storage_blobs.key LIKE ?", "singing/share_images/%")
        .where("active_storage_blobs.created_at <= ?", 1.day.ago)
        .find_each do |blob|
          blob.purge
          stats[:orphan_blob_purge_count] += 1
        rescue StandardError => e
          stats[:error_count] += 1
          Rails.logger.error(
            "[Singing::CleanupExpiredShareImagesJob] orphan blob cleanup failed " \
            "blob_id=#{blob.id} error=#{e.class.name}: #{e.message}"
          )
        end
    end
  end
end
