# 手動承認プロジェクトへの承認待ち申請(コミュニティの Permit に相当)。
# 承認・却下・本人の取り消しで行を消すため、却下後は再申請できる(アクセス停止とは区別する)。
# 再申請は新しい行になるので、以前の申請メッセージは引き継がれない。
class ProjectJoinRequest < ApplicationRecord
  MESSAGE_MAX_LENGTH = 500

  belongs_to :project
  belongs_to :customer

  validates :customer_id, uniqueness: { scope: :project_id }
  validates :message, length: { maximum: MESSAGE_MAX_LENGTH }

  before_validation { self.message = message.to_s.strip.presence }

  after_destroy_commit -> { JoinRequestNotifications.resolve_project!(applicant_id: customer_id, project_id: project_id) }
end
