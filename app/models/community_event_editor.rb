class CommunityEventEditor < ApplicationRecord
  belongs_to :customer
  belongs_to :community

  validates :customer_id, uniqueness: { scope: :community_id }

  # オーナー(owner_id/CommunityOwner)や管理者は既にイベント編集以上の権限を持つため、
  # 重複してイベント編集者(マネージャー)に設定する必要がない。
  # 公開側の自己申告制イベント編集者機能は廃止済みのため、現在は管理画面側
  # (Admin::CustomersController、is_owner: managerの担当コミュニティ設定)からのみ参照する。
  def self.assignable?(customer, community)
    return false if customer.blank? || community.blank?
    return false if customer.admin?
    return false if community.owner_id == customer.id

    !community.owners.exists?(id: customer.id)
  end
end
