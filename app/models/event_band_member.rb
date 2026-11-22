# バンド出演枠のパート担当者。会員(customer)か、未登録の出演者の表示名(display_name)のどちらかを持つ。
class EventBandMember < ApplicationRecord
  DISPLAY_NAME_MAX_LENGTH = 50

  belongs_to :event_band, inverse_of: :members
  belongs_to :customer, optional: true

  validates :part_name, presence: true, inclusion: { in: JoinPart::NAME_OPTIONS }
  validates :part_name, uniqueness: { scope: :event_band_id }
  validates :display_name, length: { maximum: DISPLAY_NAME_MAX_LENGTH }, allow_blank: true
  validate :customer_or_display_name_present
  # 新しく選んだときだけ確認する。登録後に担当者が退会しても、バンド名など他の更新まで保存不能にしないため
  # (Song#requested_by_customer と同じ考え方)。
  validate :customer_must_be_hosting_member, if: -> { customer_id.present? && will_save_change_to_customer_id? }

  def customer_member?
    customer.present? && !customer.is_deleted?
  end

  # 退会した会員を担当にしていた場合は、名前を出さずに「退会済み」とだけ表示する。
  def label
    return customer.name if customer_member?
    return "退会済みの会員" if customer.present?

    display_name
  end

  private

  def customer_or_display_name_present
    return if customer_id.present? || display_name.present?

    errors.add(:base, "#{part_name}の担当者を選ぶか、表示名を入力してください")
  end

  def customer_must_be_hosting_member
    event = event_band&.event
    return if event.blank?
    return if event.hosting_community_members.exists?(id: customer_id)

    errors.add(:base, "#{part_name}の担当者は開催コミュニティの有効なメンバーから選んでください")
  end
end
