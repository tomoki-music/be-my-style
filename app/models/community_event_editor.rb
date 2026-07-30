class CommunityEventEditor < ApplicationRecord
  belongs_to :customer
  belongs_to :community

  validates :customer_id, uniqueness: { scope: :community_id }

  # オーナー(owner_id/CommunityOwner)や管理者は既にイベント編集以上の権限を持つため、
  # 重複してイベント編集者に設定する必要がない。公開側(Public::CommunityEventEditorsController)と
  # 管理画面側(Admin::CustomersController)の両方から参照し、登録可能条件を一致させる。
  def self.assignable?(customer, community)
    return false if customer.blank? || community.blank?
    return false if customer.admin?
    return false if community.owner_id == customer.id

    !community.owners.exists?(id: customer.id)
  end
end
