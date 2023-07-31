class Activity < ApplicationRecord
  has_one_attached :activity_video
  has_one_attached :activity_image

  belongs_to :customer

  validate :activity_video_size

  def activity_video_size
    if activity_video.blob.byte_size > 10.megabytes
      errors.add(:activity_video, "は1つのファイル10MB以内にしてください")
    end
  end
end
