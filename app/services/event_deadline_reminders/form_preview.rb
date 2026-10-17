module EventDeadlineReminders
  # イベント編集画面の「送信予定日時・状態・送信メッセージ」の見込みを、保存前の入力値
  # (未保存の Event / リマインド)から計算する。DBへの書き込みと送信は一切しない。
  # 初期表示とプレビューAPIの両方で使い、表示を食い違わせない。
  class FormPreview
    attr_reader :event, :reminder

    def initialize(event:, reminder:, now: Time.current)
      @event = event
      @reminder = reminder
      @now = now
    end

    def scheduled_at
      @reminder.scheduled_at
    end

    # 状態表示用のリマインド。未送信なら保存時と同じ送信可否(arming)の判定を写しに対して行い、
    # 送信中・送信済み・失敗は設定を変えても状態が変わらないため保存済みの状態をそのまま使う。
    def status_reminder
      return @reminder unless @reminder.pending?

      @status_reminder ||= begin
        copy = EventDeadlineReminder.new(@reminder.attributes.except("id", "lead_hours", "created_at", "updated_at"))
        copy.lead_hours = @reminder.lead_hours_before_type_cast
        # event= だと has_many 側にも写しが追加されフォームに混ざるため、参照だけ持たせる。
        copy.association(:event).target = @event
        copy.sync_arming(now: @now, change: @event.deadline_reminder_schedule_change(@reminder, saved: false))
        copy
      end
    end

    # 締め切り・送信タイミングが無効ならメッセージは作れない(本文の日付が決まらないため)。
    def message
      return if @reminder.deadline.blank? || @event.event_start_time.blank?

      @message ||= MessageBuilder.call(
        event: @event, kind: @reminder.kind, sent_at: preview_sent_at, custom_message: @reminder.custom_message
      )
    end

    # 送信中・送信済みは、実際に送った(送っている)内容を表示する。
    def sent_message
      @reminder.snapshot_message unless @reminder.pending?
    end

    # 入力値の検証エラー(リマインド単体分)。保存はしない。
    def errors
      return [] if @reminder.valid?

      @reminder.errors.full_messages
    end

    private

    # 「本日」「明日」の判定は送信予定日時を基準にする(過ぎていれば現在)。
    def preview_sent_at
      [scheduled_at || @now, @now].max
    end
  end
end
