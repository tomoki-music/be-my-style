module Chat
  module LinkPreviews
    # 曲(Song)は自ドメインのDBレコードなので外部HTTP通信を行わず、DBから直接解決する。
    # EventFetcherと異なりLinkDetector側では存在確認を行っていないため、ここでのNotFoundErrorは
    # 「そもそも存在しないURL」「削除済み」の両方で通常経路として発生し得る
    # (LinkPreviewSyncServiceが捕捉してstatus: failedにするため、投稿自体は失敗しない)。
    class SongFetcher
      class NotFoundError < StandardError; end

      def self.call(url)
        new.call(url)
      end

      def self.synchronous?
        true
      end

      def call(url)
        song = find_song(url)
        raise NotFoundError, "Song not found for url=#{url}" if song.blank?

        {
          title: song.song_name,
          author_name: song.artist_name,
          thumbnail_url: nil
        }
      end

      private

      # URL上のevent_idとSongが実際に所属するevent_idが一致する場合のみ解決する。
      # event_idを無視してid検索のみを行うと、/public/events/1/songs/999 のように
      # 実在するが別イベント配下のSong IDを流用して曲カードを偽装できてしまうため。
      def find_song(url)
        uri = URI.parse(url)
        match = uri.path.match(Chat::LinkDetector::SONG_PATH_PATTERN)
        return nil if match.nil?

        event_id, song_id = match[1], match[2]
        Song.find_by(id: song_id, event_id: event_id)
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
