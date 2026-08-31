# 本番DBの読み取り専用監査(2026-08)で「本来同一の楽曲が別SongMasterへ分裂している」ことを
# 確認した6組。左が正、右が統合元。統合方向は 統合元 -> 正。
# 監査で曲名・アーティスト・キー表記を突き合わせ、6組すべて同一楽曲と判断済み。
# song_masters:merge_known_duplicates タスクでのみ参照する(定数はrakeのnamespace/taskブロック内では
# 定義できないためファイルスコープに置く)。
KNOWN_DUPLICATE_SONG_MASTER_MERGES = [
  { canonical_id: 43,  duplicate_id: 398, note: "GLAMOROUS SKY／中島美嘉" },
  { canonical_id: 93,  duplicate_id: 102, note: "unravel／TK from 凛として時雨" },
  { canonical_id: 139, duplicate_id: 162, note: "八月、某、月明かり／ヨルシカ" },
  { canonical_id: 140, duplicate_id: 239, note: "Cause We've Ended as Lovers／Jeff Beck" },
  { canonical_id: 176, duplicate_id: 203, note: "Fly Me To The Moon／Key of C major" },
  { canonical_id: 318, duplicate_id: 324, note: "ワタリドリ／[Alexandros]" }
].freeze

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

  # 本番監査で確認した「本来同一の楽曲が別SongMasterへ分裂している」6組
  # (KNOWN_DUPLICATE_SONG_MASTER_MERGES)を、正SongMasterへ統合する。
  #
  # 分裂の原因は、SongMasters::Resolver.normalize が「曲名／アーティスト」併記・引用符・括弧・
  # 区切り文字のゆれを、意味的表記ゆれの誤統合を避けるためあえて吸収しないこと。単純に統合元を
  # 削除するだけだと、同じ旧表記のSongが再保存されたときにSongMasterが再作成され再分裂する。
  # そのため統合元の正規化キーを SongMasterAlias として正SongMasterへ恒久的に向ける。
  # 実処理は SongMasters::Merge に委譲する(トランザクション・行ロック・UNIQUE衝突デデュープ・
  # 未知参照時のロールバック・統合後の検算はそちらを参照)。
  #
  # 使い方:
  #   DRY_RUN=true bundle exec rails song_masters:merge_known_duplicates  # 予定のみ表示(DBは一切変更しない)
  #   bundle exec rails song_masters:merge_known_duplicates               # 統合を実行(1組ずつ独立トランザクション)
  #
  # 本番DBに適用する前に、必ずステージング/ローカルで DRY_RUN の結果を確認すること。
  desc "本番監査で確認した分裂SongMaster 6組を正SongMasterへ統合する(DRY_RUN=trueで予定のみ)"
  task merge_known_duplicates: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    log = lambda do |message|
      puts message
      Rails.logger.info("[song_masters:merge_known_duplicates] #{message}")
    end

    log.call(dry_run ? "DRY RUNモードで実行します(DBは一切変更しません)" : "分裂SongMasterの統合を実行します")

    summary = { performed: 0, already_merged: 0, blocked: 0 }

    KNOWN_DUPLICATE_SONG_MASTER_MERGES.each do |pair|
      log.call("")
      log.call("=== #{pair[:note]} : SongMaster##{pair[:duplicate_id]} -> SongMaster##{pair[:canonical_id]} ===")

      result = SongMasters::Merge.call(
        canonical_id: pair[:canonical_id],
        duplicate_id: pair[:duplicate_id],
        dry_run: dry_run,
        logger: log
      )

      if result.performed
        summary[:performed] += 1
      elsif result.already_merged
        summary[:already_merged] += 1
      elsif !dry_run && !result.executable?
        summary[:blocked] += 1
        log.call("!! 実行不可のためスキップしました: #{result.aborted_reason}")
      end
    end

    log.call("")
    log.call(
      "完了しました " \
      "(#{dry_run ? '判定のみ' : "統合#{summary[:performed]}組 / 統合済み#{summary[:already_merged]}組 / 実行不可#{summary[:blocked]}組"})"
    )
  end
end
