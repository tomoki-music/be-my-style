module EventDeadlineReminders
  # 送信時点でのリマインド・イベントの状態を再確認し、送ってはいけない理由を返す(送れるなら nil)。
  # 画面表示にも同じ理由を使う。
  #
  # イベントに「非公開」「開催中止」を表すカラムは存在しない(削除はレコード削除で、
  # その場合リマインドも dependent: :destroy で消える)ため、判定対象は開始済み・締め切り済み等に限る。
  class Eligibility
    REASON_LABELS = {
      disabled: "自動リマインドが無効です",
      no_deadline: "締め切りが未設定です",
      already_processed: "送信済みのため再送しません",
      not_armed: "送信予定日時を過ぎてから有効化・締め切り変更されたため自動送信しません",
      before_schedule: "送信予定日時になっていません",
      deadline_passed: "締め切りを過ぎたため送信しません",
      event_started: "イベントの開始日時を過ぎたため送信しません",
      community_missing: "開催コミュニティが見つからないため送信しません"
    }.freeze

    def self.reason(reminder, now: Time.current)
      new(reminder, now).reason
    end

    def initialize(reminder, now)
      @reminder = reminder
      @event = reminder.event
      @now = now
    end

    def reason
      return :disabled unless @reminder.enabled?
      return :no_deadline if @reminder.deadline.blank?
      return :already_processed if @reminder.sent? || @reminder.failed?
      return :deadline_passed if @reminder.deadline <= @now
      return :event_started if @event.event_start_time <= @now
      return :not_armed unless @reminder.armed?
      return :before_schedule if @reminder.scheduled_at > @now
      return :community_missing if @event.community.blank?

      nil
    end
  end
end
