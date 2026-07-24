module Chat
  module LinkPreviews
    # provider(enum値)からFetcherクラスを解決する。Spotify/Apple Music/イベントカード等の
    # 将来追加はFETCHERSにFetcherクラスを足すだけで済み、呼び出し側(Job)の変更は不要になる。
    class ProviderResolver
      FETCHERS = {
        "youtube" => YoutubeFetcher,
        "event" => EventFetcher
      }.freeze

      def self.fetcher_for(provider)
        FETCHERS.fetch(provider.to_s) do
          raise ArgumentError, "Unsupported link preview provider: #{provider}"
        end
      end
    end
  end
end
