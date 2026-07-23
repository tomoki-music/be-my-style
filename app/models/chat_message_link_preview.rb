class ChatMessageLinkPreview < ApplicationRecord
  belongs_to :chat_message

  enum provider: { youtube: 0, spotify: 1, apple_music: 2, soundcloud: 3, event: 4 }
  enum status: { pending: 0, fetched: 1, failed: 2 }

  # 動画ID単位のキャッシュ共有・再取得判定(Chat::LinkPreviewSyncService)で使う期限。
  CACHE_EXPIRES_IN = 30.days

  validates :url, :external_id, :position, presence: true

  def cache_fresh?
    fetched? && fetched_at.present? && fetched_at > CACHE_EXPIRES_IN.ago
  end
end
