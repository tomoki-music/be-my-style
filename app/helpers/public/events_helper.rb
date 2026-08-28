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

  # 固定パート列(JoinPart::NAME_OPTIONS)ごとに、その列へ表示すべきJoinPartを返す。
  #
  # 2025年1月のセレクトボックス化以前の自由入力("ボーカル"等)も、PartNameNormalizerで
  # 正規化した結果が列名と一致すれば同じ固定列へ寄せる。生の完全一致
  # (jp.join_part_name == part_name)だと旧表記が「該当パートなし(ー)」に落ちてしまう。
  # 意味を一意に決められない旧表記(normalizeがnilを返す値)は、従来どおりどの固定列にも出さない。
  #
  # 旧表記と新表記が同じ曲に併存し、同じ正規化パートになるケースがあり得るため配列で返し、
  # 呼び出し側が各JoinPartを個別に描画する(1件だけ黙って捨てない)。
  # song.join_partsはコントローラでpreload済みのため追加SQLは発生しない。
  def normalized_join_parts_for_column(song, column_name)
    song.join_parts.select do |join_part|
      PerformanceHistory::PartNameNormalizer.normalize(join_part.join_part_name) == column_name
    end
  end

  # セル内「演奏経験のある人」表示用の集合。基礎集合(ExperiencedCustomersQuery)から、
  # そのセルの現在の参加者をCustomer IDで差し引く(同じセルで参加者表示と経験者表示を
  # 二重に出さない)。exclude_customer_idsは呼び出し側がpreload済みの
  # join_part.customersから組み立てるため、追加SQLは発生しない。
  def experienced_customers_for_display(song, raw_part_name, exclude_customer_ids: [])
    customers = experienced_customers_for(song, raw_part_name)
    return customers if exclude_customer_ids.blank?

    excluded = exclude_customer_ids.to_set
    customers.reject { |customer| excluded.include?(customer.id) }
  end

  # 主催者向けエントリー依頼候補の「表示状態」。checkboxの有効・無効とバッジ文言だけを決める。
  # 送信可否の最終判断はサーバー側(TargetResolver / BatchSender / Sender)が独立して再計算する。
  #
  # 参照するのは @entry_invitations_by_key(コントローラで1クエリ取得済み)と、
  # preload済みのjoin_part.customers / song.join_parts のみ。候補ごとの追加SQLは発生させない。
  #
  # 優先順位:
  #   1. already_entered(データ不整合時の防御。通常は現在参加者を集合から除外済み)
  #   2. event_ended
  #   3. part_closed
  #   4. recently_invited
  #   5. invited_resendable
  #   6. invitable
  EntryInvitationCandidateState = Struct.new(:key, :checkbox_enabled, :badge, keyword_init: true)

  def entry_invitation_candidate_state(song, join_part, customer, current_member_ids: [])
    if current_member_ids.include?(customer.id)
      return EntryInvitationCandidateState.new(key: :already_entered, checkbox_enabled: false, badge: "エントリー済み")
    end

    if @event&.ended?
      return EntryInvitationCandidateState.new(key: :event_ended, checkbox_enabled: false, badge: nil)
    end

    unless song.recruiting_join_parts.any? { |part| part.id == join_part.id }
      return EntryInvitationCandidateState.new(key: :part_closed, checkbox_enabled: false, badge: "募集終了")
    end

    invitation = entry_invitation_for(song, join_part, customer)
    if invitation&.within_resend_window?
      return EntryInvitationCandidateState.new(key: :recently_invited, checkbox_enabled: false, badge: "依頼済み")
    end

    if invitation.present?
      return EntryInvitationCandidateState.new(key: :invited_resendable, checkbox_enabled: true, badge: "再依頼可")
    end

    EntryInvitationCandidateState.new(key: :invitable, checkbox_enabled: true, badge: nil)
  end

  # 楽曲表内に「いま選択できる(チェックボックスが有効な)エントリー依頼候補」が1人でもいるか。
  # Viewの列描画(normalized_join_parts_for_column)と同じ経路でたどり、実際にチェックボックスが
  # 描画されるセルだけを対象に entry_invitation_candidate_state.checkbox_enabled を数える。
  #
  # 参照するのは @experienced_customers_by_song_part / @entry_invitations_by_key と
  # preload済みの song.join_parts・join_part.customers のみで、候補ごとの追加SQLは発生させない。
  # このフラグは送信ボタンのdisabled表示(UX補助)に使うだけで、送信可否の最終判断は
  # サーバー側(TargetResolver / BatchSender / Sender)が独立して再検証する。
  def entry_invitation_has_selectable_candidate?
    return @entry_invitation_has_selectable_candidate if defined?(@entry_invitation_has_selectable_candidate)

    @entry_invitation_has_selectable_candidate =
      @event.songs.any? do |song|
        JoinPart::NAME_OPTIONS.any? do |column_name|
          normalized_join_parts_for_column(song, column_name).any? do |join_part|
            member_ids = join_part.customers.map(&:id)
            candidates = experienced_customers_for_display(
              song, join_part.join_part_name, exclude_customer_ids: member_ids
            )
            Array(candidates).any? do |customer|
              entry_invitation_candidate_state(
                song, join_part, customer, current_member_ids: member_ids
              ).checkbox_enabled
            end
          end
        end
      end
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
