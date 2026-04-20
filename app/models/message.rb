class Message < ApplicationRecord
  include Stampable

  belongs_to :customer
  belongs_to :post

  validate :body_or_stamp_present

  private

  def body_or_stamp_present
    return if body.present? || stamped?

    errors.add(:base, "コメントを入力してください")
  end
end
