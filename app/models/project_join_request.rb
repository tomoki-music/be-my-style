# 手動承認プロジェクトへの承認待ち申請(コミュニティの Permit に相当)。
# 承認・却下・本人の取り消しで行を消すため、却下後は再申請できる(アクセス停止とは区別する)。
class ProjectJoinRequest < ApplicationRecord
  belongs_to :project
  belongs_to :customer

  validates :customer_id, uniqueness: { scope: :project_id }

  after_destroy_commit -> { JoinRequestNotifications.resolve_project!(applicant_id: customer_id, project_id: project_id) }
end
