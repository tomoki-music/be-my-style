module EventDeadlineReminders
  # 確保済み(sending)のリマインドを、対象メンバーへ1人1通ずつメールで送る。
  #
  # 受信者ごとに「送信前に履歴行(sending)を作る → 送る → delivered/failed に更新」の順で処理する。
  # 送信後・更新前にプロセスが止まった場合、その行は sending のまま残る。引き継いだ実行は
  # 実際に届いたか判断できないため failed(結果不明)にし、再送はしない(重複より取りこぼしを選ぶ)。
  class MailDeliverer
    INTERRUPTED_REASON = "送信処理が中断され結果が不明なため、重複防止のため再送しません".freeze
    STOPPED_REASON = "途中で自動リマインドが無効化されたため、送信を中断しました".freeze

    def initialize(reminder, now: Time.current)
      @reminder = reminder
      @event = reminder.event
      @now = now
    end

    def call
      mark_interrupted_deliveries
      resolver = RecipientResolver.new(@event)
      processed_ids = @reminder.deliveries.pluck(:customer_id).to_set
      note = nil

      resolver.call.each do |customer|
        next if processed_ids.include?(customer.id)

        unless heartbeat
          note = STOPPED_REASON
          break
        end

        deliver_to(customer, resolver)
      end

      finalize!(note: note)
    end

    def finalize!(note: nil)
      counts = @reminder.deliveries.group(:status).count.transform_keys(&:to_s)
      delivered = counts["delivered"].to_i
      failed = counts["failed"].to_i
      all_failed = delivered.zero? && failed.positive?

      @reminder.update!(
        status: all_failed ? :failed : :sent,
        sent_at: Time.current,
        sent_channel: :mail,
        sent_for_deadline: @reminder.deadline,
        delivered_count: delivered,
        failed_count: failed,
        failure_reason: note || (all_failed ? "すべての受信者への送信に失敗しました" : nil)
      )
    end

    private

    def mark_interrupted_deliveries
      @reminder.deliveries.sending.update_all(
        status: EventDeadlineReminderDelivery.statuses[:failed],
        failure_reason: INTERRUPTED_REASON,
        updated_at: Time.current
      )
    end

    # 受信者ごとに started_at を更新し、送信に時間がかかっても別の実行に「停止した」と
    # 判定されて引き継がれないようにする。無効化されていれば 0 件更新となり false を返す。
    def heartbeat
      EventDeadlineReminder.where(id: @reminder.id, enabled: true, status: EventDeadlineReminder.statuses[:sending])
                           .update_all(started_at: Time.current) == 1
    end

    def deliver_to(customer, resolver)
      delivery = begin
        @reminder.deliveries.create!(customer: customer, status: :sending)
      rescue ActiveRecord::RecordNotUnique
        return # 別の実行がこの受信者を処理済み
      end

      unless resolver.eligible?(customer)
        delivery.update!(status: :skipped, failure_reason: "送信直前の確認で配信対象外になりました")
        return
      end

      unless delivery_allowed?
        delivery.update!(status: :skipped, failure_reason: "非本番環境のため送信をスキップしました")
        return
      end

      begin
        EventDeadlineReminderMailer.with(delivery: delivery, message: message).remind.deliver_now
      rescue StandardError => e
        Rails.logger.error("[EventDeadlineReminders::MailDeliverer] delivery=#{delivery.id} #{e.class}: #{e.message}")
        delivery.update!(status: :failed, failure_reason: "#{e.class}: #{e.message}".truncate(250))
        return
      end

      delivery.update!(status: :delivered, delivered_at: Time.current)
    end

    def message
      @message ||= MessageBuilder.call(event: @event, kind: @reminder.kind, sent_at: @now)
    end

    # 開発環境は実際の Gmail SMTP 設定のため、実在ユーザーへの誤送信を防ぐ
    # (EntryInvitations::Sender と同じ方針)。test は delivery_method=:test のため許可する。
    def delivery_allowed?
      Rails.env.production? ||
        Rails.env.test? ||
        ENV["EVENT_DEADLINE_REMINDER_ALLOW_REAL_EMAILS"].to_s.strip.length.positive?
    end
  end
end
