module Chat
  # チャットメッセージ集合が参照している曲リンクカード(provider: :song)分のSongを一括ロードする。
  # カードごとにSong.find_byを繰り返すとメッセージ件数分のN+1が発生するため、描画対象の
  # メッセージ一覧をまとめて渡して1回で解決する。関連イベント名・募集中パート表示に必要な
  # event/join_parts/customersもここでincludesし、View側でのN+1を防ぐ。
  class SongLinkPreviewLoader
    def self.call(chat_messages)
      new(chat_messages).call
    end

    def initialize(chat_messages)
      @chat_messages = chat_messages
    end

    def call
      Song.includes(:event, join_parts: :customers)
          .where(id: song_ids)
          .index_by { |song| song.id.to_s }
    end

    private

    def song_ids
      Array(@chat_messages)
        .flat_map(&:chat_message_link_previews)
        .select(&:song?)
        .map(&:external_id)
        .uniq
    end
  end
end
