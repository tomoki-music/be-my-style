module Singing
  class CleanupExpiredShareImagesJob < ApplicationJob
    queue_as :default

    def perform
      SingingShareImage.expired_for_cleanup.find_each do |share_image|
        share_image.image.purge if share_image.image.attached?
        share_image.destroy!
      end
    end
  end
end
