module Public::EventsHelper
  # カード描画に必要な値だけをViewへ渡す。YouTube URLが無い/解析できない場合はnilを返し、
  # 呼び出し側(View)はカードを描画しないだけで済む(fallbackロジックをHamlに書かせない)。
  YoutubeCardData = Struct.new(:thumbnail_url, :video_url, :title, :author_name, keyword_init: true)

  def youtube_card_for(song)
    return nil if song.youtube_url.blank?

    resolved = Youtube::UrlResolver.call(song.youtube_url)
    return nil if resolved.nil?

    YoutubeCardData.new(
      thumbnail_url: resolved.thumbnail_url,
      video_url: resolved.canonical_url,
      title: song.song_name.presence || "YouTubeで動画を見る",
      author_name: song.artist_name.presence
    )
  end
end
