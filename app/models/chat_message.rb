class ChatMessage < ApplicationRecord
  include Stampable

  belongs_to :chat_room
  belongs_to :customer
  belongs_to :community, optional: true
  belongs_to :reply_to_chat_message, class_name: "ChatMessage", optional: true, counter_cache: :replies_count

  has_many :chat_mentions, dependent: :destroy
  has_many :mentioned_customers, through: :chat_mentions
  has_many :replies, class_name: "ChatMessage", foreign_key: :reply_to_chat_message_id, dependent: :nullify

  has_many_attached :attachments

  # plain: Markdown対応以前の投稿(互換性維持のため常にプレーンテキスト表示)
  # markdown: Markdown対応後の投稿(Chat::MarkdownRendererでHTML変換して表示)
  enum content_format: { plain: 0, markdown: 1 }

  validate :content_or_stamp_or_attachment_present

  # スレッドの親(最上位の通常メッセージ)を返す。返信は常にスレッド親を
  # reply_to_chat_message_idに保存する設計(Chat::ReplyTargetResolverで正規化)だが、
  # 既存データや手動でのDB改変等による循環参照でも安全に終了できるよう、辿ったID自体を
  # 記録して「一度見たIDに戻ろうとした時点」で打ち切る(単なる深さ上限だけだと、
  # 循環の周期によっては自分自身を指す行を生成しかねないため、実際に閉路を検出する)。
  MAX_THREAD_DEPTH = 50

  def thread_root
    root = self
    visited_ids = { root.id => true }

    loop do
      parent = root.reply_to_chat_message
      break if parent.blank?
      break if visited_ids[parent.id]
      break if visited_ids.size >= MAX_THREAD_DEPTH

      visited_ids[parent.id] = true
      root = parent
    end

    root
  end

  # 通常のチャット一覧に表示する対象(スレッドの返信を除いた親メッセージ)。
  scope :thread_roots, -> { where(reply_to_chat_message_id: nil) }

  private

  def content_or_stamp_or_attachment_present
    return if content.present? || stamped? || attachments.attached?

    errors.add(:base, "メッセージを入力してください")
  end
end
