module Chat
  # チャットメッセージ集合が参照しているイベントリンクカード(provider: :event)分の
  # Eventを一括ロードする。カードごとにEvent.find_byを繰り返すとメッセージ件数分の
  # N+1が発生するため、描画対象のメッセージ一覧をまとめて渡して1回で解決する。
  class EventLinkPreviewLoader
    def self.call(chat_messages)
      new(chat_messages).call
    end

    def initialize(chat_messages)
      @chat_messages = chat_messages
    end

    def call
      Event.includes(:community).with_attached_event_image.where(id: event_ids).index_by { |event| event.id.to_s }
    end

    private

    def event_ids
      Array(@chat_messages)
        .flat_map(&:chat_message_link_previews)
        .select(&:event?)
        .map(&:external_id)
        .uniq
    end
  end
end
