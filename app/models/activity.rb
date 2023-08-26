class Activity < ApplicationRecord
  has_one_attached :activity_video
  has_one_attached :activity_image

  belongs_to :customer

  validates :title, presence: true
  validates :keep, presence: true
  validates :problem, presence: true
  validates :try, presence: true
  validate :activity_video_size

  def activity_video_size
    return unless activity_video.attached?
    if activity_video.byte_size > 10.megabytes
      errors.add(:activity_video, "は1ファイル10MB以内にしてください")
    end
  end
end
