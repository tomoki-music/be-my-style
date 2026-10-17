class EventDeadlineReminder < ApplicationRecord
  # 締め切りの何時間前に送るか(主催者が種別ごとに設定する)。
  DEFAULT_LEAD_HOURS = 12
  LEAD_HOURS_RANGE = (1..168).freeze
  CUSTOM_MESSAGE_MAX_LENGTH = 5_000
  # 送信処理中(sending)のまま止まった(プロセス強制終了・サーバー停止等)とみなし、
  # 次回の定期実行が引き継いでよい経過時間。定期実行間隔(5分)より十分長くする。
  STALE_SENDING_AFTER = 15.minutes
  TIME_ZONE = "Asia/Tokyo".freeze

  KIND_LABELS = { "request" => "曲リクエスト締め切り", "entry" => "エントリー締め切り" }.freeze
  CHANNEL_LABELS = { "mail" => "メール", "chat" => "コミュニティチャット" }.freeze
  # 送信中は変更を受け付けない設定(配信中の受信者ごとに内容・条件が混在しないようにする)。
  LOCKED_WHILE_SENDING = %w[lead_hours custom_message channel].freeze

  belongs_to :event, inverse_of: :deadline_reminders
  belongs_to :chat_message, optional: true
  has_many :deliveries, class_name: "EventDeadlineReminderDelivery", dependent: :destroy

  serialize :message_snapshot, JSON

  enum kind: { request: 0, entry: 1 }, _prefix: :kind
  enum channel: { mail: 0, chat: 1 }, _prefix: :channel
  enum sent_channel: { mail: 0, chat: 1 }, _prefix: :sent_via
  # pending: 未送信 / sending: 送信処理中 / sent: 送信済み / failed: 失敗(自動再送しない)
  enum status: { pending: 0, sending: 1, sent: 2, failed: 3 }
  # enabled_after_schedule: 送信予定日時を過ぎてから有効化された
  # deadline_changed_past: 締め切り変更で送信予定日時が過去になった
  # lead_time_changed_past: 送信タイミング(何時間前)の変更で送信予定日時が過去になった
  enum disarm_reason: { enabled_after_schedule: 0, deadline_changed_past: 1, lead_time_changed_past: 2 }, _prefix: :disarmed_by

  validates :kind, presence: true, uniqueness: { scope: :event_id }
  validates :channel, presence: true
  validate :lead_hours_must_be_in_range
  validate :custom_message_within_limit
  validate :kind_cannot_change, on: :update
  validate :settings_locked_while_sending, on: :update

  # フォームから想定外の値が送られても ArgumentError(500)にせず、presence の検証エラーにする。
  def kind=(value)
    super(self.class.kinds.key?(value.to_s) ? value : nil)
  end

  def channel=(value)
    super(self.class.channels.key?(value.to_s) ? value : nil)
  end

  # 改行コードを揃え、前後の空白(全角スペースを含む)を除く。空白だけの入力は未設定(自動生成)として扱う。
  def self.normalize_custom_message(value)
    value.to_s.gsub(/\r\n?/, "\n").gsub(/\A[[:space:]]+|[[:space:]]+\z/, "").presence
  end

  def custom_message=(value)
    super(self.class.normalize_custom_message(value))
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

  def custom_message?
    custom_message.present?
  end

  def deadline
    return if event.blank? || kind.blank?

    kind_request? ? event.request_deadline : event.event_entry_deadline
  end

  def lead_time
    lead_hours_valid? ? lead_hours.hours : nil
  end

  def scheduled_at
    deadline && lead_time && (deadline - lead_time)
  end

  # 現在の締め切り・送信タイミングに対して送信待ちの状態か(定期実行で送られうるか)。
  # どちらかが記録時から変わっていれば送らない。
  def armed?
    enabled? && scheduled_at.present? && armed_deadline.present? &&
      armed_deadline.to_i == deadline.to_i && armed_lead_hours == lead_hours
  end

  # 送信待ちとして記録した送信予定日時(定期実行が送信対象を選ぶ基準)。
  def armed_scheduled_at
    armed_deadline && armed_lead_hours && (armed_deadline - armed_lead_hours.hours)
  end

  # 有効化・締め切り変更・送信タイミング変更・保存のたびに呼ぶ。送信予定日時がまだ未来の
  # 場合だけ armed_* に記録し、過去なら記録しない(=自動では即送信しない)。
  # すでに現在の設定で armed なら何もしないので、送信予定を過ぎてから別項目を編集しても
  # 定期処理停止からの復旧送信の対象から外れない。送信処理を始めた後は一切触らない。
  #
  # change: 今回の保存で何が変わったか(Event#deadline_reminder_schedule_change)。
  #   :enabled / :deadline / :lead_time / nil。過去になった理由の表示に使う。
  def sync_arming(now: Time.current, change: nil)
    return unless pending?

    if !enabled? || scheduled_at.blank?
      assign_attributes(armed_deadline: nil, disarm_reason: nil)
    elsif armed?
      self.disarm_reason = nil
    elsif scheduled_at > now
      assign_attributes(armed_deadline: deadline, armed_lead_hours: lead_hours, disarm_reason: nil)
    else
      assign_attributes(armed_deadline: nil, disarm_reason: disarm_reason_for(change))
    end
  end

  # 配信開始時に件名・本文・配信方法を確定して保存する。停止後に別の実行が引き継いだ場合も
  # この内容で送り、途中で設定が変わっても受信者ごとに内容が混在しないようにする。
  def message_snapshot!(now:)
    return message_snapshot if message_snapshot.present?

    message = EventDeadlineReminders::MessageBuilder.call(
      event: event, kind: kind, sent_at: now, custom_message: custom_message
    )
    snapshot = {
      "channel" => channel,
      "lead_hours" => lead_hours,
      "custom" => custom_message?,
      "subject" => message.subject,
      "body" => message.body,
      "chat_body" => message.chat_body
    }
    update_columns(message_snapshot: snapshot)
    snapshot
  end

  def snapshot_message
    return if message_snapshot.blank?

    EventDeadlineReminders::MessageBuilder::Message.new(
      subject: message_snapshot["subject"], body: message_snapshot["body"], chat_body: message_snapshot["chat_body"]
    )
  end

  private

  def lead_hours_valid?
    errors_for_lead_hours.nil?
  end

  # 小数("1.5")は integer 型変換で 1 になってしまうため、変換前の値で判定する。
  def errors_for_lead_hours
    raw = lead_hours_before_type_cast
    raw = raw.to_s.strip unless raw.is_a?(Integer)
    return "を入力してください" if raw.is_a?(String) && raw.empty?
    return "は整数で入力してください" unless raw.is_a?(Integer) || raw.match?(/\A-?\d+\z/)

    value = raw.to_i
    return "は#{LEAD_HOURS_RANGE.min}〜#{LEAD_HOURS_RANGE.max}時間の範囲で入力してください" unless LEAD_HOURS_RANGE.cover?(value)

    nil
  end

  def lead_hours_must_be_in_range
    message = errors_for_lead_hours
    errors.add(:base, "#{kind_label}の自動リマインドの送信タイミング#{message}") if message
  end

  def custom_message_within_limit
    return if custom_message.to_s.length <= CUSTOM_MESSAGE_MAX_LENGTH

    errors.add(:base, "#{kind_label}の自動リマインドの送信メッセージは#{CUSTOM_MESSAGE_MAX_LENGTH.to_s(:delimited)}文字以内で入力してください" \
                      "（現在#{custom_message.length.to_s(:delimited)}文字）")
  end

  def disarm_reason_for(change)
    case change
    when :enabled then :enabled_after_schedule
    when :deadline then :deadline_changed_past
    when :lead_time then :lead_time_changed_past
    else disarm_reason.presence || :enabled_after_schedule
    end
  end

  def kind_cannot_change
    errors.add(:kind, "は変更できません") if will_save_change_to_kind?
  end

  def settings_locked_while_sending
    return unless attribute_in_database(:status) == "sending"
    return if LOCKED_WHILE_SENDING.none? { |attribute| will_save_change_to_attribute?(attribute) }

    errors.add(:base, "#{kind_label}の自動リマインドは送信中のため、送信タイミング・配信方法・メッセージを変更できません。送信完了後に確認してください")
  end
end
