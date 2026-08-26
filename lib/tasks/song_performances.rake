namespace :song_performances do
  # 今回の機能追加以前に開催された、終了済みイベントのJoinPartCustomer(実際のパートエントリー)を
  # 演奏実績(SongPerformance)へ反映する。
  #
  # 使い方:
  #   bundle exec rails song_performances:backfill
  #   DRY_RUN=true bundle exec rails song_performances:backfill   # 更新せず件数のみ確認
  #
  # 対象:
  #   - 終了済み(event_end_time <= 現在時刻)のイベントのみ
  #   - 退会済み(is_deleted)customerは対象外
  #   - エントリー取消済み(JoinPartCustomerが既に存在しない)分は、そもそも対象に上がらない
  #
  # 何度実行しても重複しない(SongPerformances::EventSyncが、SongPerformance側のUNIQUE制約と
  # 同じキーでfind_or_initialize相当の判定をしたうえで作成するため、既存分はスキップされる)。
  desc "終了済みイベントのエントリー情報を演奏実績(SongPerformance)へ反映する"
  task backfill: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    log = lambda do |message|
      puts message
      Rails.logger.info("[song_performances:backfill] #{message}")
    end

    log.call(dry_run ? "DRY RUNモードで実行します(実際の登録は行いません)" : "バックフィルを開始します")

    total_target = 0
    total_created = 0
    total_skipped = 0
    errors = 0

    Event.where("event_end_time <= ?", Time.current).find_each do |event|
      result = SongPerformances::EventSync.call(event, dry_run: dry_run)
      total_target += result.target
      total_created += result.created
      total_skipped += result.skipped
    rescue StandardError => e
      errors += 1
      log.call("Event##{event.id} の反映に失敗しました: #{e.class}: #{e.message}")
    end

    log.call("対象件数(終了済みイベントのエントリー): #{total_target}件")
    log.call(dry_run ? "登録予定件数: #{total_created}件" : "新規登録件数: #{total_created}件")
    log.call("スキップ件数(登録済み等): #{total_skipped}件")
    log.call("エラー件数: #{errors}件") if errors > 0
    log.call("完了しました")
  end
end
