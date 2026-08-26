namespace :song_masters do
  # SongMasterの重複"候補"を検出し、レポートするだけのread-onlyタスク。
  #
  # SongMasters::Resolver.normalizeは意味的な表記ゆれ(丸の内/丸ノ内、略称/正式名称、
  # feat.表記の有無、同名異曲、邦題/原題、読み仮名による一致等)を意図的に自動統合しない。
  # そのため、本来「同じ曲」であっても正規化キーが一致せず、別々のSongMaster行として
  # 登録されてしまうケースが起こりうる。
  #
  # このタスクは、正規化キーより緩い基準(記号・空白違いを無視した曲名の緩い一致)で
  # 「同じ曲の可能性がある」候補をグルーピングして一覧表示するだけで、
  # 削除・統合等のデータ変更は一切行わない(手動マージUIは別途の対応とする)。
  #
  # 使い方:
  #   bundle exec rails song_masters:duplicate_candidates
  desc "SongMasterの重複候補(曲名が緩く一致するもの)を検出してレポートする(read-only)"
  task duplicate_candidates: :environment do
    log = lambda { |message| puts message }

    # 記号・空白・末尾の"feat."節を除いた緩いキーでグルーピングする。
    # 完全一致(SongMasters::Resolver.normalize)より緩いだけで、これも「同じ曲だと確定した」
    # わけではない。あくまで人が確認すべき候補の絞り込みに使う。
    loose_key = lambda do |song_name|
      song_name.to_s.unicode_normalize(:nfkc).downcase
        .gsub(/[[:space:]]/, "")
        .gsub(/[\p{Punct}\p{S}]/, "")
    end

    groups = SongMaster.all.group_by { |master| loose_key.call(master.song_name) }
    candidates = groups.select { |key, masters| key.present? && masters.size > 1 }

    if candidates.empty?
      log.call("重複候補は見つかりませんでした(対象SongMaster: #{SongMaster.count}件)。")
      next
    end

    log.call("重複候補グループ: #{candidates.size}件(対象SongMaster: #{SongMaster.count}件)")
    log.call("※ここに表示されるのはあくまで「曲名が緩く一致する」候補です。")
    log.call("  同名異曲・邦題/原題・読み仮名一致等で意味的には別曲の場合もあるため、")
    log.call("  自動統合はせず、必ず人が内容を確認してください。")
    log.call("")

    candidates.each do |_key, masters|
      log.call("--- 候補グループ (#{masters.size}件) ---")
      masters.each do |master|
        song_count = master.songs.count
        customer_song_part_count = master.customer_song_parts.count
        log.call(
          "  SongMaster##{master.id} song_name=#{master.song_name.inspect} " \
          "artist_name=#{master.artist_name.inspect} " \
          "songs=#{song_count}件 customer_song_parts=#{customer_song_part_count}件"
        )
      end
    end

    log.call("")
    log.call("完了しました(データは変更していません)。")
  end

  # 既存Song(song_master_id未設定)を一括でSongMasterへ紐付けるタスク。
  #
  # 新規・更新Songは Song#assign_song_master(before_validationコールバック)が自動で解決するため、
  # このタスクの対象は「PR導入前から存在する既存Song」のみ。
  #
  # 画面表示のたびに無制限なDB更新を行わない設計にしたため(PerformanceHistoryの各Query Objectは
  # 読み取り専用)、既存データの紐付けはこの冪等なRakeタスクに閉じる。
  # 既にsong_master_idが設定済みのSongはスキップするため、何度実行しても安全。
  #
  # 使い方:
  #   bundle exec rails song_masters:backfill_songs
  #   DRY_RUN=true bundle exec rails song_masters:backfill_songs   # 更新せず件数のみ確認
  desc "song_master_id未設定の既存SongをSongMasterへ一括紐付けする"
  task backfill_songs: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    log = lambda do |message|
      puts message
      Rails.logger.info("[song_masters:backfill_songs] #{message}")
    end

    log.call(dry_run ? "DRY RUNモードで実行します(実際の更新は行いません)" : "バックフィルを開始します")

    target = 0
    resolved = 0
    unresolved = 0

    Song.where(song_master_id: nil).find_each do |song|
      target += 1

      song_master = SongMasters::Resolver.call(song_name: song.song_name, artist_name: song.artist_name)
      if song_master.blank?
        unresolved += 1
        next
      end

      song.update_column(:song_master_id, song_master.id) unless dry_run
      resolved += 1
    end

    log.call("対象件数(song_master_id未設定のSong): #{target}件")
    log.call(dry_run ? "紐付け予定件数: #{resolved}件" : "紐付け件数: #{resolved}件")
    log.call("解決できなかった件数(曲名が空等): #{unresolved}件") if unresolved > 0
    log.call("完了しました")
  end
end
