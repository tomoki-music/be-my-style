module Public::EventsHelper
  # カード描画に必要な値だけをViewへ渡す。YouTube URLが無い/解析できない場合はnilを返し、
  # 呼び出し側(View)はカードを描画しないだけで済む(fallbackロジックをHamlに書かせない)。
  YoutubeCardData = Struct.new(:thumbnail_url, :video_url, :title, :author_name, keyword_init: true)

  # @experienced_customers_by_song_part(PerformanceHistory::ExperiencedCustomersQuery#call
  # の戻り値)から、表示中の曲・パートに対応する経験者一覧を取り出す。
  #
  # キー生成をQuery::key_forに一元化することで、Hamlが生のjoin_part_nameのまま
  # (パート名の表記ゆれを正規化せずに)キーを組み立てて参照キーがずれる事故を防ぐ
  # (例: 過去イベント側が旧表記"ボーカル"で登録されており、現在イベント側も同じ
  # "ボーカル"のままの場合、正規化しないと一致しない)。
  def experienced_customers_for(song, raw_part_name)
    key = PerformanceHistory::ExperiencedCustomersQuery.key_for(song.song_master_id, raw_part_name)
    return [] if key.nil?

    @experienced_customers_by_song_part[key]
  end

  # 表示中の曲・パート・経験者に対する直近のエントリー依頼メール送信レコードを返す(無ければ nil)。
  # コントローラで1クエリ取得済みの @entry_invitations_by_key(キー: [song_id, join_part_id, customer_id])
  # のみを参照し、曲数×パート数×経験者数分の追加クエリを発生させない。
  def entry_invitation_for(song, join_part, customer)
    (@entry_invitations_by_key || {})[[song.id, join_part.id, customer.id]]
  end

  # エントリー依頼パネル(_entry_invitation_panel)に表示する、経験者ごとの送信状態バッジ文言。
  # 戻り値: 文言(String) / nil(未送信)
  def entry_invitation_status_label(invitation)
    return nil if invitation.nil?
    return "送信失敗" if invitation.failed?
    return nil if invitation.sent_at.blank?

    "依頼済み（#{l(invitation.sent_at, format: :short)}）"
  end

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
