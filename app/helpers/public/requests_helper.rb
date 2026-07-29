module Public::RequestsHelper
  # requests.request は自由記述のため、Song#youtube_urlのような専用カラムではなく
  # 本文中からURLを検出する必要がある。Youtube::UrlResolver(単一URL文字列専用)ではなく、
  # 自由文中の複数URLスキャンを責務とするChat::LinkDetectorを再利用する。
  def youtube_card_for_request(request)
    return nil if request.request.blank?

    detected = Chat::LinkDetector.call(request.request).find { |candidate| candidate.provider == :youtube }
    return nil if detected.nil?

    Public::EventsHelper::YoutubeCardData.new(
      thumbnail_url: "https://img.youtube.com/vi/#{detected.external_id}/hqdefault.jpg",
      video_url: detected.url,
      title: "YouTubeで動画を見る",
      author_name: request.customer.name.presence
    )
  end
end
