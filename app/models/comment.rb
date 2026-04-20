class Comment < ApplicationRecord
  include Stampable

  belongs_to :customer
  belongs_to :activity

  validate :comment_or_stamp_present

  private

  def comment_or_stamp_present
    return if comment.present? || stamped?

    errors.add(:base, "コメントを入力してください")
  end
end
