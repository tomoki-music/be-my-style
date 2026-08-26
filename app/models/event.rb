class Event < ApplicationRecord
  # 表示優先順位: 終了済み > 開催中 > 募集終了 > 開催予定。募集人数・満員概念は持たない
  # (既存のindexアクションと同じevent_end_time/event_entry_deadline比較のみを使う)。
  STATUS_LABELS = {
    ended: "終了済み",
    ongoing: "開催中",
    entry_closed: "募集終了",
    upcoming: "開催予定"
  }.freeze

  has_one_attached :event_image
  has_many :songs, -> { order(position: :asc) }, dependent: :destroy, inverse_of: :event
  # Event -> Song -> JoinPart。join/join_confirmで送信されたjoin_part_idが
  # このイベント配下のものかをスコープ付きクエリで検証するために使う
  # (Public::EventsController#valid_join_part_ids_for)。
  has_many :join_parts, through: :songs
  has_many :requests, dependent: :destroy
  # 演奏実績は、Event削除後も履歴として残すためnullify(song_templates.source_song_idと同じ考え方)。
  has_many :song_performances, dependent: :nullify
  belongs_to :customer
  belongs_to :community

  accepts_nested_attributes_for :songs, allow_destroy: true, reject_if: :all_blank

  # 「終了していない」イベント(開催中を含む)。#status_keyの:ended判定
  # (event_end_time <= now)と揃え、event_end_time > nowを終了していない条件とする。
  scope :upcoming_or_ongoing, ->(now = Time.current) { where("events.event_end_time > ?", now) }

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

  private

  def customer_must_be_active
    errors.add(:customer, "は退会済みのため設定できません") if customer.present? && customer.is_deleted?
  end

  public

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
end
