class EventDeadlineReminder < ApplicationRecord
  # 締め切りの何時間前に送るか。
  LEAD_TIME = 12.hours
  # 送信処理中(sending)のまま止まった(プロセス強制終了・サーバー停止等)とみなし、
  # 次回の定期実行が引き継いでよい経過時間。定期実行間隔(5分)より十分長くする。
  STALE_SENDING_AFTER = 15.minutes
  TIME_ZONE = "Asia/Tokyo".freeze

  KIND_LABELS = { "request" => "曲リクエスト締め切り", "entry" => "エントリー締め切り" }.freeze
  CHANNEL_LABELS = { "mail" => "メール", "chat" => "コミュニティチャット" }.freeze

  belongs_to :event, inverse_of: :deadline_reminders
  belongs_to :chat_message, optional: true
  has_many :deliveries, class_name: "EventDeadlineReminderDelivery", dependent: :destroy

  enum kind: { request: 0, entry: 1 }, _prefix: :kind
  enum channel: { mail: 0, chat: 1 }, _prefix: :channel
  enum sent_channel: { mail: 0, chat: 1 }, _prefix: :sent_via
  # pending: 未送信 / sending: 送信処理中 / sent: 送信済み / failed: 失敗(自動再送しない)
  enum status: { pending: 0, sending: 1, sent: 2, failed: 3 }
  # enabled_after_schedule: 送信予定日時を過ぎてから有効化された
  # deadline_changed_past: 締め切り変更で送信予定日時が過去になった
  enum disarm_reason: { enabled_after_schedule: 0, deadline_changed_past: 1 }, _prefix: :disarmed_by

  validates :kind, presence: true, uniqueness: { scope: :event_id }
  validates :channel, presence: true
  validate :kind_cannot_change, on: :update

  # フォームから想定外の値が送られても ArgumentError(500)にせず、presence の検証エラーにする。
  def kind=(value)
    super(self.class.kinds.key?(value.to_s) ? value : nil)
  end

  def channel=(value)
    super(self.class.channels.key?(value.to_s) ? value : nil)
  end

  def self.kind_label(kind)
    KIND_LABELS.fetch(kind.to_s, "締め切り")
  end

  def kind_label
    self.class.kind_label(kind)
  end

  def channel_label
    CHANNEL_LABELS.fetch(channel.to_s)
  end

  def deadline
    return if event.blank? || kind.blank?

    kind_request? ? event.request_deadline : event.event_entry_deadline
  end

  def scheduled_at
    deadline && (deadline - LEAD_TIME)
  end

  # 現在の締め切りに対して送信待ちの状態か(定期実行で送られうるか)。
  def armed?
    enabled? && deadline.present? && armed_deadline.present? && armed_deadline.to_i == deadline.to_i
  end

  # 有効化・締め切り変更・保存のたびに呼ぶ。送信予定日時(締め切り-12時間)がまだ未来の
  # 場合だけ armed_deadline に締め切りを記録し、過去なら記録しない(=自動では即送信しない)。
  # すでに現在の締め切りで armed なら何もしないので、送信予定を過ぎてから別項目を編集しても
  # 定期処理停止からの復旧送信の対象から外れない。送信処理を始めた後は一切触らない。
  def sync_arming(now: Time.current, deadline_changed: false)
    return unless pending?

    if !enabled? || deadline.blank?
      self.armed_deadline = nil
      self.disarm_reason = nil
    elsif armed?
      self.disarm_reason = nil
    elsif scheduled_at > now
      self.armed_deadline = deadline
      self.disarm_reason = nil
    else
      self.armed_deadline = nil
      self.disarm_reason =
        if deadline_changed
          :deadline_changed_past
        else
          disarm_reason.presence || :enabled_after_schedule
        end
    end
  end

  private

  def kind_cannot_change
    errors.add(:kind, "は変更できません") if will_save_change_to_kind?
  end
end
