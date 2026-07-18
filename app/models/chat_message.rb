class ChatMessage < ApplicationRecord
  include Stampable

  belongs_to :chat_room
  belongs_to :customer
  belongs_to :community, optional: true
  belongs_to :reply_to_chat_message, class_name: "ChatMessage", optional: true

  has_many :chat_mentions, dependent: :destroy
  has_many :mentioned_customers, through: :chat_mentions
  has_many :replies, class_name: "ChatMessage", foreign_key: :reply_to_chat_message_id, dependent: :nullify

  has_many_attached :attachments

  # plain: Markdown対応以前の投稿(互換性維持のため常にプレーンテキスト表示)
  # markdown: Markdown対応後の投稿(Chat::MarkdownRendererでHTML変換して表示)
  enum content_format: { plain: 0, markdown: 1 }

  validate :content_or_stamp_or_attachment_present

  private

  def content_or_stamp_or_attachment_present
    return if content.present? || stamped? || attachments.attached?

    errors.add(:base, "メッセージを入力してください")
  end
end
