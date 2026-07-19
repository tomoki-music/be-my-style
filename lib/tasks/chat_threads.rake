namespace :chat do
  # 既存の返信チェーンをスレッドの親(thread_root)へ正規化し、replies_countを再計算する。
  # Phase3導入時、既存の「返信への返信」データが残っている場合に1回だけ実行する想定。
  #
  # 使い方:
  #   bundle exec rails chat:normalize_reply_threads
  #   DRY_RUN=true bundle exec rails chat:normalize_reply_threads   # 更新せず件数のみ確認
  #
  # 何度実行しても結果は変わらない(冪等)。既に正規化済みのレコードは対象から自然に外れ、
  # replies_countは毎回「その時点の実データ」から再計算するため、増分ではなく上書きになる。
  desc "既存の返信チェーンをスレッドの親(thread_root)へ正規化し、replies_countを再計算する"
  task normalize_reply_threads: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    normalized = 0
    broken = 0
    errors = 0

    log = lambda do |message|
      puts message
      Rails.logger.info("[chat:normalize_reply_threads] #{message}")
    end

    log.call(dry_run ? "DRY RUNモードで実行します(実際の更新は行いません)" : "正規化を開始します")

    # find_eachはデフォルトで1,000件ずつバッチ取得するため、大量データでも
    # 全件を一括でメモリに読み込まない。
    ChatMessage.where.not(reply_to_chat_message_id: nil).find_each do |message|
      root = message.thread_root

      if root.id == message.id
        # 循環参照等、壊れたデータによってthread_rootが自分自身に解決された場合
        # (通常のアプリコードでは発生し得ない、手動でのDB改変等を想定した保険)。
        # 自己参照行を残さず、安全側に倒して返信リンクを解除する。
        broken += 1
        message.update_column(:reply_to_chat_message_id, nil) unless dry_run
        next
      end

      next if root.id == message.reply_to_chat_message_id

      normalized += 1
      message.update_column(:reply_to_chat_message_id, root.id) unless dry_run
    rescue StandardError => e
      errors += 1
      log.call("ChatMessage##{message.id} の正規化に失敗しました: #{e.class}: #{e.message}")
    end

    log.call("正規化した返信(返信への返信 -> スレッド親へ付け替え): #{normalized}件")
    log.call("自己参照等の壊れたデータとして返信リンクを解除: #{broken}件")

    if dry_run
      log.call("DRY RUNのためreplies_countの再計算はスキップしました")
    else
      # 再計算が必要な対象は2種類ある:
      #   (1) 正規化後、現に誰かの親になっているメッセージ(distinct pluckで取得)
      #   (2) 正規化前は親だったが、子の付け替えによって親でなくなり、replies_countが
      #       古い値のまま残ってしまっているメッセージ(replies_count > 0で検出)
      # (1)だけを対象にすると、(2)のような「付け替えで子を失った旧親」のカウントが
      # 古いまま取り残されてしまう。
      root_ids = ChatMessage.where.not(reply_to_chat_message_id: nil).distinct.pluck(:reply_to_chat_message_id)
      stale_ids = ChatMessage.where("replies_count > 0").pluck(:id)
      target_ids = (root_ids + stale_ids).uniq

      target_ids.each_slice(1000).with_index do |ids_batch, batch_index|
        ids_batch.each do |id|
          ChatMessage.reset_counters(id, :replies)
        rescue StandardError => e
          errors += 1
          log.call("ChatMessage##{id} のreplies_count再計算に失敗しました: #{e.class}: #{e.message}")
        end
        log.call("replies_count再計算: #{[(batch_index + 1) * 1000, target_ids.size].min}/#{target_ids.size}件 完了")
      end
      log.call("replies_countを再計算した対象メッセージ: #{target_ids.size}件")
    end

    log.call("エラー件数: #{errors}件") if errors > 0
    log.call("完了しました")
  end
end
