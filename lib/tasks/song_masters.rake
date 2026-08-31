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

  # 既存SongをSongMasterへ(再)紐付けし、参照が無くなったSongMasterを整理するタスク。
  #
  # 新規・更新Songは Song#assign_song_master(before_validationコールバック)が自動で解決するが、
  # Resolverの解決ロジック改善前に登録されたSongは、現在では別扱いになったSongMasterへ
  # 紐付いたままになりうる。このタスクで現在の正しいSongMasterへ寄せ直す。
  #
  # 画面表示のたびに無制限なDB更新を行わない設計にしたため(PerformanceHistoryの各Query Objectは
  # 読み取り専用)、既存データの紐付けはこの冪等なRakeタスクに閉じる。
  # 実処理は SongMasters::BackfillSongs に委譲する(dry-run制御・トランザクション・
  # 孤立SongMaster削除の安全策はそちらを参照)。
  #
  # 使い方:
  #   bundle exec rails song_masters:backfill_songs                     # 再リンクのみ(SongMasterは削除しない)
  #   DRY_RUN=true bundle exec rails song_masters:backfill_songs        # DBを一切変更せず予定のみ表示
  #   DELETE_ORPHANS=true bundle exec rails song_masters:backfill_songs # 再リンク + 孤立SongMaster削除
  #
  # 再リンクと孤立SongMaster削除は分離している。デフォルトは再リンクのみで、
  # 孤立SongMasterの物理削除は DELETE_ORPHANS=true を明示したときだけ実施する
  # (再リンク後にデータ・実ブラウザ確認をしてから削除を判断する運用のため)。
  desc "既存SongをSongMasterへ(再)紐付けする(DELETE_ORPHANS=trueで孤立SongMasterも削除)"
  task backfill_songs: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    delete_orphans = ENV["DELETE_ORPHANS"] == "true"

    log = lambda do |message|
      puts message
      Rails.logger.info("[song_masters:backfill_songs] #{message}")
    end

    mode =
      if dry_run
        "DRY RUNモードで実行します(DBは一切変更しません)"
      elsif delete_orphans
        "バックフィルを開始します(再リンク + 孤立SongMaster削除)"
      else
        "バックフィルを開始します(再リンクのみ。孤立SongMasterは削除しません)"
      end
    log.call(mode)
    SongMasters::BackfillSongs.call(dry_run: dry_run, delete_orphans: delete_orphans, logger: log)
  end

  # 曲名の表記パターンと、Resolver改善によるSongMaster集約の変化を集計してレポートするだけの
  # read-onlyタスク。DBは一切変更しない。出力は Song ID・song_name・artist_name のみ。
  #
  # 使い方:
  #   bundle exec rails song_masters:analyze_titles
  desc "曲名の表記パターンとResolver改善前後のSongMaster集約変化を集計する(read-only)"
  task analyze_titles: :environment do
    SongMasters::TitleAnalysis.call(logger: ->(message) { puts message })
  end

  # MERGE_PAIRS で明示的に渡した「本来同一の楽曲が別SongMasterへ分裂している」ペアを、
  # 正(keep)SongMaster へ統合する。全ペアを単一トランザクションで適用し、1組でも失敗したら
  # 6組すべてロールバックする。実処理は SongMasters::MergeBatch / SongMasters::Merge に委譲する。
  #
  # 分裂の原因は、SongMasters::Resolver.normalize が「曲名／アーティスト」併記・引用符・括弧・
  # 区切り文字のゆれを、意味的表記ゆれの誤統合を避けるためあえて吸収しないこと。単純に統合元を
  # 削除するだけだと、同じ旧表記のSongが再保存されたときにSongMasterが再作成され再分裂するため、
  # 統合元の正規化キーを SongMasterAlias として正SongMaster へ恒久的に向ける。
  #
  # 統合対象は MERGE_PAIRS で必ず明示的に渡す(本番IDをタスクにハードコードしない。全SongMasterや
  # 検出候補を自動統合しない)。形式は "keep:merge" のカンマ区切り。
  #   MERGE_PAIRS="43:398,93:102,139:162,140:239,176:203,318:324"
  #
  # 実行モード:
  #   - 環境変数なし(または DRY_RUN=true) → DRY RUN。DBを一切変更しない。
  #   - 本適用は APPLY=true と CONFIRM=MERGE_SONG_MASTERS の「両方」が必須。
  #     片方だけ・DRY_RUN との矛盾・中途半端な指定はエラーで停止する(黙って本適用しない)。
  #
  # 使い方:
  #   # DRY RUN(DB変更なし)
  #   MERGE_PAIRS="43:398,93:102,139:162,140:239,176:203,318:324" \
  #     bundle exec rails song_masters:merge_pairs
  #
  #   # 本適用(全ペア単一トランザクション。1組でも失敗したら全ロールバック)
  #   MERGE_PAIRS="43:398,93:102,139:162,140:239,176:203,318:324" \
  #     APPLY=true CONFIRM=MERGE_SONG_MASTERS \
  #     bundle exec rails song_masters:merge_pairs
  desc "MERGE_PAIRS(keep:merge のカンマ区切り)の分裂SongMasterペアを統合する。既定はDRY RUN。本適用は APPLY=true CONFIRM=MERGE_SONG_MASTERS が必須"
  task merge_pairs: :environment do
    log = lambda do |message|
      puts message
      Rails.logger.info("[song_masters:merge_pairs] #{message}")
    end

    begin
      batch = SongMasters::MergeBatch.from_env(env: ENV, logger: log)
    rescue SongMasters::MergeBatch::ConfigError => e
      abort "[song_masters:merge_pairs] #{e.message}"
    end

    log.call(
      batch.apply? ?
        "本適用モードで実行します(APPLY=true / CONFIRM 一致)。全ペア単一トランザクション。" :
        "DRY RUN モードで実行します(DBは一切変更しません)。"
    )

    result = batch.call

    if batch.apply?
      abort "[song_masters:merge_pairs] 本適用は行われませんでした: #{result.aborted_reason}" unless result.applied
      log.call("完了しました(#{result.pair_results.size}組を統合)。")
    else
      unless result.ready
        abort "[song_masters:merge_pairs] 実行不可のペアがあります。本適用すると全体が中止されます。"
      end
      log.call("完了しました(DRY RUN。全ペア実行可能。DBは変更していません)。")
    end
  end
end
