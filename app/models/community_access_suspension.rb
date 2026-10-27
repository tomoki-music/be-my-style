# Business コミュニティの運営者によるアクセス停止。行がある間は、承認方式に関わらず参加・申請できない。
class CommunityAccessSuspension < ApplicationRecord
  belongs_to :community
  belongs_to :customer
  belongs_to :suspended_by, class_name: "Customer", optional: true

  validates :customer_id, uniqueness: { scope: :community_id }
end
