module Chat
  module LinkPreviews
    # イベントは自ドメインのDBレコードなので外部HTTP通信を行わず、DBから直接解決する。
    # LinkDetector側で存在確認済みのため、ここでのNotFoundErrorは検出からDB保存までの
    # 間にEventが削除された場合の防御用(通常経路では発生しない)。
    class EventFetcher
      class NotFoundError < StandardError; end

      def self.call(url)
        new.call(url)
      end

      def self.synchronous?
        true
      end

      def call(url)
        event = find_event(url)
        raise NotFoundError, "Event not found for url=#{url}" if event.blank?

        {
          title: event.event_name,
          author_name: event.community.name,
          thumbnail_url: thumbnail_url_for(event)
        }
      end

      private

      def find_event(url)
        uri = URI.parse(url)
        match = uri.path.match(Chat::LinkDetector::EVENT_PATH_PATTERN)
        return nil if match.nil?

        Event.find_by(id: match[1])
      rescue URI::InvalidURIError
        nil
      end

      def thumbnail_url_for(event)
        return nil unless event.event_image.attached?

        Rails.application.routes.url_helpers.rails_blob_path(event.event_image, only_path: true)
      end
    end
  end
end
