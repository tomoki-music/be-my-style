class Permit < ApplicationRecord
  belongs_to :customer
  belongs_to :community

  # 承認・却下・取り消し・アクセス停止のどれで申請が無くなっても、承認する人のベルに未読で残さない。
  after_destroy_commit -> { JoinRequestNotifications.resolve_community!(applicant_id: customer_id, community_id: community_id) }
end
