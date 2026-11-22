class Event < ApplicationRecord
  # 表示優先順位: 終了済み > 開催中 > 募集終了 > 開催予定。募集人数・満員概念は持たない
  # (既存のindexアクションと同じevent_end_time/event_entry_deadline比較のみを使う)。
  STATUS_LABELS = {
    ended: "終了済み",
    ongoing: "開催中",
    entry_closed: "募集終了",
    upcoming: "開催予定"
  }.freeze

  # 参加者本人が取消できるのは開始時刻のこの期間より前まで。
  # 楽曲表の「削除」ボタン表示とPublic::EventsController#deleteの両方がこの判定を使う。
  JOIN_CANCELLATION_DEADLINE = 7.days

  HOSTING_COMMUNITY_ID_FORMAT = /\A[1-9]\d*\z/

  has_one_attached :event_image
  has_many :songs, -> { order(position: :asc) }, dependent: :destroy, inverse_of: :event
  # Event -> Song -> JoinPart。join/join_confirmで送信されたjoin_part_idが
  # このイベント配下のものかをスコープ付きクエリで検証するために使う
  # (Public::EventsController#valid_join_part_ids_for)。
  has_many :join_parts, through: :songs
  has_many :requests, dependent: :destroy
  belongs_to :customer
  # 主催コミュニティ。編集権限・リマインド送信先・テンプレート・ランキングなどの基準はここだけを見る。
  # 開催コミュニティ(event_communities)を追加しても、それらの基準は広がらない。
  belongs_to :community
  has_many :event_communities, -> { order(:id) }, dependent: :destroy, inverse_of: :event
  has_many :deadline_reminders, class_name: "EventDeadlineReminder", dependent: :destroy, inverse_of: :event

  accepts_nested_attributes_for :songs, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :deadline_reminders

  # 「終了していない」イベント(開催中を含む)。#status_keyの:ended判定
  # (event_end_time <= now)と揃え、event_end_time > nowを終了していない条件とする。
  scope :upcoming_or_ongoing, ->(now = Time.current) { where("events.event_end_time > ?", now) }

  # 指定コミュニティが開催コミュニティに含まれるイベント。JOIN しないので、複数のコミュニティに
  # 該当しても同じイベントは1件だけ返る。旧コードが作成した行の無いイベントも主催コミュニティで拾う。
  scope :hosted_by, lambda { |community_ids|
    where(
      id: Event.unscoped.where(community_id: community_ids)
        .or(Event.unscoped.where(id: EventCommunity.where(community_id: community_ids).select(:event_id)))
        .select(:id)
    )
  }

  geocoded_by :address
  after_validation :geocode, if: :address_changed?

  with_options presence: true do
    validates :event_name
    validates :event_start_time
    validates :event_end_time
    validates :event_entry_deadline
    validates :entrance_fee
    validates :address
    validates :songs
  end

  # customer_id(イベント投稿者)を新規設定・変更する時だけ有効ユーザーかを検証する。
  # Song#requested_by_customer_must_be_eligible_memberと同じ考え方で、
  # 既存イベントの投稿者が退会・論理削除された後の無関係な更新まで
  # 巻き込んで保存不能にしないため(退会後も履歴として表示し続ける方針)。
  validate :customer_must_be_active, if: :will_save_change_to_customer_id?
  validate :enabled_deadline_reminders_require_deadline
  validate :hosting_communities_must_be_consistent

  after_save :sync_event_communities

  # autosave(nested attributes)によるリマインド保存の後に走らせるため、
  # has_many/accepts_nested_attributes_for より後ろで after_save として宣言する。
  after_save :sync_deadline_reminder_arming

  private

  # 保存後の組み合わせで検証する。共催先の指定を省いて主催だけを変える更新も対象にする。
  def hosting_communities_must_be_consistent
    return if @selected_cohost_community_ids.nil? && !will_save_change_to_community_id?

    if @selected_cohost_community_ids_malformed
      errors.add(:base, "共催先の指定が正しくありません")
      return
    end

    final_ids = resulting_hosting_community_ids
    domain_id_by_community = Community.where(id: final_ids).pluck(:id, :domain_id).to_h
    if (final_ids - [community_id] - domain_id_by_community.keys).any?
      errors.add(:base, "存在しないコミュニティが共催先に含まれています")
    elsif domain_id_by_community.values.uniq.size > 1
      errors.add(:base, "異なるサービスのコミュニティは共催先にできません")
    end
  end

  # 主催は community_id だけで決まり、共催先の指定内容で解除も切り替えもされない。
  # 主催を変更したときの旧主催は、keep_previous_primary_as_cohost で明示した場合だけ共催先に残す。
  def calculate_hosting_community_ids(current:, previous_primary:)
    cohosts = (@selected_cohost_community_ids || current) - [previous_primary, community_id]
    cohosts |= [previous_primary] if previous_primary && @keep_previous_primary_as_cohost == true
    [community_id].compact | cohosts
  end

  # 保存と同じトランザクションで反映する(has_many の *_ids= は保存前に即時反映されてしまうため使わない)。
  def sync_event_communities
    return if @selected_cohost_community_ids.nil? && !saved_change_to_community_id?

    current = EventCommunity.where(event_id: id).pluck(:community_id)
    previous_primary = community_id_before_last_save if saved_change_to_community_id?
    desired = calculate_hosting_community_ids(current: current, previous_primary: previous_primary)

    EventCommunity.where(event_id: id, community_id: current - desired).delete_all
    (desired - current).each { |hosting_id| add_event_community(hosting_id) }

    @selected_cohost_community_ids = nil
    @keep_previous_primary_as_cohost = nil
    association(:event_communities).reset
  end

  def add_event_community(hosting_id)
    EventCommunity.transaction(requires_new: true) { EventCommunity.create!(event_id: id, community_id: hosting_id) }
  rescue ActiveRecord::RecordNotUnique
    nil # 同時更新で先に同じ行が作られた場合は、目的の状態になっているので何もしない
  end

  def enabled_deadline_reminders_require_deadline
    deadline_reminders.each do |reminder|
      next if reminder.marked_for_destruction? || !reminder.enabled?
      next if reminder.deadline.present?

      errors.add(:base, "#{reminder.kind_label}が未設定のため、#{reminder.kind_label}の自動リマインドは有効にできません")
    end
  end

  def sync_deadline_reminder_arming
    now = Time.current
    deadline_reminders.each do |reminder|
      next unless reminder.persisted?

      reminder.sync_arming(now: now, change: deadline_reminder_schedule_change(reminder, saved: true))
      reminder.save! if reminder.changed?
    end
  end

  def customer_must_be_active
    errors.add(:customer, "は退会済みのため設定できません") if customer.present? && customer.is_deleted?
  end

  public

  # 主催コミュニティを先頭にした開催コミュニティの一覧。主催は event_communities の行の有無に
  # 関わらず含める(マイグレーション後〜Puma 再起動前に旧コードが作ったイベントにも対応するため)。
  def all_hosting_communities
    ([community] + event_communities.map(&:community)).compact.uniq
  end

  def all_hosting_community_ids
    ([community_id] + event_communities.map(&:community_id)).compact.uniq
  end

  def hosting_community_names(separator = " / ")
    all_hosting_communities.map(&:name).join(separator)
  end

  # 主催を除いた開催コミュニティ。
  def cohost_communities
    all_hosting_communities - [community]
  end

  # 保存済みの主催。管理画面で主催の変更がエラーになり再表示するときも、変更前の主催を指す。
  def primary_community_in_database
    community_id_changed? ? Community.find_by(id: community_id_in_database) : community
  end

  # 編集フォームの共催先欄の選択状態。入力エラーで再表示するときは入力値を優先する。
  def selected_cohost_community_ids
    @selected_cohost_community_ids || (all_hosting_community_ids - [community_id_in_database])
  end

  # 値を受け取るだけで、反映は save の検証を通った後に行う。呼び出してよいのはサイト管理者の操作のみ
  # (Customer#can_manage_event_hosting_communities? で許可されたときだけ permit する)。
  # 主催の ID が含まれていても無視するので、この値で主催が外れたり変わったりすることはない。
  def selected_cohost_community_ids=(values)
    raw_ids = Array(values).map { |value| value.to_s.strip }.reject(&:blank?)
    @selected_cohost_community_ids_malformed = raw_ids.any? { |value| !value.match?(HOSTING_COMMUNITY_ID_FORMAT) }
    @selected_cohost_community_ids = raw_ids.grep(HOSTING_COMMUNITY_ID_FORMAT).map(&:to_i).uniq
  end

  # 管理画面の主催変更用。フォームの初期値は「残す」だが、指定が無いリクエストでは残さない。
  def keep_previous_primary_as_cohost
    @keep_previous_primary_as_cohost.nil? ? true : @keep_previous_primary_as_cohost
  end

  def keep_previous_primary_as_cohost=(value)
    @keep_previous_primary_as_cohost = ActiveModel::Type::Boolean.new.cast(value)
  end

  # 共催先に選べる候補。主催と同じドメイン(music など)に限り、主催は含めない。
  def cohost_community_options
    primary = primary_community_in_database
    return Community.none if primary.blank?

    Community.where(domain_id: primary.domain_id).where.not(id: primary.id).order(:name)
  end

  # この保存で確定する開催コミュニティ。未保存の共催先・主催の指定を反映する。
  def resulting_hosting_community_ids
    previous_primary = community_id_in_database if will_save_change_to_community_id?
    calculate_hosting_community_ids(current: event_communities.map(&:community_id), previous_primary: previous_primary)
  end

  # この保存で確定する開催コミュニティのいずれかに所属する有効メンバー。
  # リクエスト者を新たに指定するときの検証に使う(同じ送信で外すコミュニティのメンバーは対象外)。
  def resulting_hosting_community_members
    Customer.active.where(id: CommunityCustomer.where(community_id: resulting_hosting_community_ids).select(:customer_id))
  end

  # 開催コミュニティのいずれかに所属する有効メンバー(複数所属でも重複しない)。
  def hosting_community_members
    Customer.active.where(id: CommunityCustomer.where(community_id: all_hosting_community_ids).select(:customer_id))
  end

  # 作成・編集フォーム用に、締め切り種別ごとのリマインド設定を(未作成なら未保存で)揃えて返す。
  def deadline_reminders_for_form
    EventDeadlineReminder.kinds.keys.map { |kind| deadline_reminder_for(kind) }
  end

  def deadline_reminder_for(kind)
    deadline_reminders.detect { |reminder| reminder.kind == kind.to_s } ||
      deadline_reminders.build(kind: kind)
  end

  # リマインドの送信予定日時に影響する変更のうち、今回の保存(saved: true)または
  # 保存前の入力(saved: false。プレビュー用)で何が変わったかを返す。
  # 有効化を最優先し(新規作成時も同様)、次に締め切り、送信タイミングの順に見る。
  def deadline_reminder_schedule_change(reminder, saved:)
    changed = lambda do |record, attribute|
      saved ? record.saved_change_to_attribute?(attribute) : record.will_save_change_to_attribute?(attribute)
    end
    deadline_attribute = reminder.kind_request? ? :request_deadline : :event_entry_deadline

    if changed.call(reminder, :enabled) then :enabled
    elsif changed.call(self, deadline_attribute) then :deadline
    elsif changed.call(reminder, :lead_hours) then :lead_time
    end
  end

  def participation_records_for(customer)
    JoinPartCustomer
      .joins(join_part: :song)
      .where(customer_id: customer.id, songs: { event_id: id })
  end

  def participation_record_for(customer)
    participation_records_for(customer)
      .order(session_credit_applied: :desc, id: :asc)
      .first
  end

  # このイベントの参加者(JoinPartCustomer経由)を重複なく返す。
  # イベントオーナー・管理者は自動的に含めない(参加者=実際にパートへjoinした人のみ)。
  # Relationを返すため、呼び出し側で.where(is_deleted: false)等をさらに絞り込める。
  def participating_customers
    Customer.where(
      id: JoinPartCustomer.joins(join_part: :song).where(songs: { event_id: id }).select(:customer_id)
    ).distinct
  end

  # @メンション機能(候補一覧・通知対象)の母集団。イベントへの参加登録の有無を問わず、
  # 開催元コミュニティの有効メンバーであるCustomerを返す(退会・論理削除済みは除外)。
  def mentionable_community_members
    community.active_customers.distinct
  end

  # 開催コミュニティのいずれかの所属者かどうか(OR 条件)。Public::EventsController#join が
  # 参加登録時に使う判定基準を1箇所に集約し、楽曲詳細ページ等の表示制御からも同じ基準を参照できるようにする。
  # 注記: このメソッドはUI表示制御(導線を出す/出さない)にのみ使う。実際の登録可否は
  # 従来どおりjoinアクション側が独立して再検証する(view側の判定だけに依存しない)。
  def community_member?(customer)
    return false if customer.blank?

    CommunityCustomer.exists?(community_id: all_hosting_community_ids, customer_id: customer.id)
  end

  def session_credit_applied_for?(customer)
    participation_record_for(customer)&.session_credit_applied?
  end

  def session_credit_amount_for(customer)
    participation_record_for(customer)&.session_credit_amount.to_i
  end

  def paid_participant_for_display?(customer)
    record = participation_record_for(customer)
    return customer.paid_plan? if record.blank?

    record.plan_snapshot.present? ? record.plan_snapshot != "free" : customer.paid_plan?
  end

  def participant_remaining_fee_for(customer)
    [entrance_fee.to_i - session_credit_amount_for(customer), 0].max
  end

  def status_key(now: Time.current)
    return :ended if event_end_time <= now
    return :ongoing if event_start_time <= now
    return :entry_closed if event_entry_deadline <= now

    :upcoming
  end

  def status_label(now: Time.current)
    STATUS_LABELS.fetch(status_key(now: now))
  end

  def ended?(now: Time.current)
    status_key(now: now) == :ended
  end

  def join_cancellable?(now: Time.current)
    event_start_time > now + JOIN_CANCELLATION_DEADLINE
  end
end
