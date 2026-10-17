module EventDeadlineReminders
  # 定期実行(bin/run_event_deadline_reminders → DispatchJob)から呼ばれ、
  # 送信予定日時(締め切り-12時間)を過ぎていて締め切り前のリマインドを送る。
  #
  # 重複送信の防止:
  #   1. 条件付き UPDATE(pending → sending)でリマインドを確保できた1プロセスだけが処理する。
  #      sending のまま STALE_SENDING_AFTER 以上経ったもの(プロセス停止等)だけは引き継げる。
  #   2. メールは受信者ごとに送信前に履歴行を作り、(リマインド, 受信者) の一意制約で二重送信を防ぐ。
  #   3. チャットは行ロック内で「未投稿」を確認してから投稿と sent への更新を同一トランザクションで行う。
  # sent / failed になったリマインドは、締め切り変更・配信方法の切り替えでも自動再送しない。
  class Dispatcher
    def self.call(now: Time.current)
      new(now: now).call
    end

    def initialize(now: Time.current)
      @now = now
    end

    # 戻り値: { processed: n, skipped: n, errored: n }
    def call
      counts = Hash.new(0)
      candidate_ids.each { |id| counts[process(id)] += 1 }
      Rails.logger.info("[EventDeadlineReminders::Dispatcher] now=#{@now.iso8601} #{counts.to_h}")
      counts
    end

    private

    def candidate_ids
      claimable_scope
        .where("armed_deadline > ? AND armed_deadline <= ?", @now, @now + EventDeadlineReminder::LEAD_TIME)
        .order(:armed_deadline, :id)
        .pluck(:id)
    end

    def claimable_scope
      statuses = EventDeadlineReminder.statuses
      EventDeadlineReminder
        .where(enabled: true)
        .where(
          "event_deadline_reminders.status = :pending OR " \
          "(event_deadline_reminders.status = :sending AND event_deadline_reminders.started_at < :stale_before)",
          pending: statuses[:pending],
          sending: statuses[:sending],
          stale_before: @now - EventDeadlineReminder::STALE_SENDING_AFTER
        )
    end

    def claim(id)
      claimable_scope.where(id: id)
                     .update_all(status: EventDeadlineReminder.statuses[:sending], started_at: @now, updated_at: @now) == 1
    end

    def process(id)
      return :skipped unless claim(id)

      reminder = EventDeadlineReminder.includes(event: :community).find_by(id: id)
      return :skipped if reminder.nil?

      reason = Eligibility.reason(reminder, now: @now)
      if reason
        release(reminder, reason)
        return :skipped
      end

      deliverer_class = reminder.channel_chat? ? ChatPoster : MailDeliverer
      deliverer_class.new(reminder, now: @now).call
      :processed
    rescue StandardError => e
      Rails.logger.error("[EventDeadlineReminders::Dispatcher] reminder=#{id} #{e.class}: #{e.message}")
      mark_failed(id, e)
      :errored
    end

    # 確保後の再確認で送れないと分かった場合。途中まで送ったメール履歴があれば
    # 送信済みとして確定し(自動再送しない)、何も送っていなければ未送信へ戻す。
    def release(reminder, reason)
      Rails.logger.info("[EventDeadlineReminders::Dispatcher] reminder=#{reminder.id} skip reason=#{reason}")
      if reminder.deliveries.exists?
        MailDeliverer.new(reminder, now: @now).finalize!(note: Eligibility::REASON_LABELS.fetch(reason))
      else
        reminder.update_columns(status: EventDeadlineReminder.statuses[:pending], started_at: nil, updated_at: @now)
      end
    end

    # 想定外の例外は自動で再試行しない(実在ユーザーへの多重送信を避けるため)。
    def mark_failed(id, error)
      EventDeadlineReminder.where(id: id, status: EventDeadlineReminder.statuses[:sending]).update_all(
        status: EventDeadlineReminder.statuses[:failed],
        failure_reason: error.message.to_s.truncate(250),
        sent_at: @now,
        updated_at: @now
      )
    rescue StandardError => e
      Rails.logger.error("[EventDeadlineReminders::Dispatcher] reminder=#{id} mark_failed #{e.class}: #{e.message}")
    end
  end
end
