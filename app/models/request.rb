class Request < ApplicationRecord
  include Stampable

  belongs_to :customer
  belongs_to :event

  validate :request_or_stamp_present

  private

  def request_or_stamp_present
    return if request.present? || stamped?

    errors.add(:base, "リクエストを入力してください")
  end
end
