class Event < ApplicationRecord
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

end
