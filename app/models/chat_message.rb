class ChatMessage < ApplicationRecord
  include Stampable

  belongs_to :chat_room
  belongs_to :customer
  belongs_to :community, optional: true

  has_many_attached :attachments

  validate :content_or_stamp_or_attachment_present

  private

  def content_or_stamp_or_attachment_present
    return if content.present? || stamped? || attachments.attached?

    errors.add(:base, "メッセージを入力してください")
  end
end
