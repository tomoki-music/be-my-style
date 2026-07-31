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
  has_many :requests, dependent: :destroy
  belongs_to :customer
  belongs_to :community

  accepts_nested_attributes_for :songs, allow_destroy: true, reject_if: :all_blank

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

  # @メンション機能(候補一覧・通知対象)の母集団。イベント参加者(participating_customers)
  # のうち、現在も開催元コミュニティの有効メンバーであるCustomerのみを返す。
  # 正規のjoinフロー(EventsController#join)では参加者は必ずコミュニティメンバーの部分集合に
  # なるが、参加後の退会・レガシーデータ・直接DB操作による不整合を考慮し、ここで改めて
  # community.customersとの積集合を取ってコミュニティ所属を保証する。
  def mentionable_participants
    participating_customers
      .where(is_deleted: false)
      .where(id: community.customers.select(:id))
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
end
