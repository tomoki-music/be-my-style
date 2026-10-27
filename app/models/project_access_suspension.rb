# Business プロジェクトの管理者によるアクセス停止。行がある間は、承認方式に関わらず参加・申請できない。
class ProjectAccessSuspension < ApplicationRecord
  belongs_to :project
  belongs_to :customer
  belongs_to :suspended_by, class_name: "Customer", optional: true

  validates :customer_id, uniqueness: { scope: :project_id }
end
