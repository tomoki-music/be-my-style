# 参加申請(コミュニティの Permit / プロジェクトの ProjectJoinRequest)を、承認できる人の通知ベル・通知一覧に出す。
# 申請者・宛先・申請先ごとに通知は1件だけにし、取り消し後の再申請では同じ通知を未読に戻して先頭へ出し直す。
# 申請が承認・却下・取り消しで無くなったら、その通知を既読にしてベルに残さない(通知自体は履歴として残す)。
class JoinRequestNotifications
  COMMUNITY_ACTION = "request".freeze
  PROJECT_ACTION = "project_request".freeze

  def self.notify!(applicant:, recipient:, action:, community_id:, project_id: nil, hidden_in_app: false)
    return if applicant.blank? || recipient.blank?
    return if recipient.id == applicant.id || recipient.is_deleted?

    notification = Notification.unscoped.where(
      visitor_id: applicant.id,
      visited_id: recipient.id,
      action: action,
      community_id: community_id,
      project_id: project_id
    ).order(:id).first_or_initialize

    notification.checked = false
    notification.hidden_in_app = hidden_in_app
    notification.created_at = Time.current if notification.persisted?
    notification.save!
    notification
  rescue ActiveRecord::RecordInvalid
    # 宛先が直前に退会した場合(Notification の検証で弾かれる)。申請そのものは止めない。
    nil
  end

  def self.resolve_community!(applicant_id:, community_id:)
    resolve!(visitor_id: applicant_id, action: COMMUNITY_ACTION, community_id: community_id)
  end

  def self.resolve_project!(applicant_id:, project_id:)
    resolve!(visitor_id: applicant_id, action: PROJECT_ACTION, project_id: project_id)
  end

  def self.resolve!(conditions)
    Notification.unscoped.where(conditions).where(checked: false).update_all(checked: true, updated_at: Time.current)
  end
  private_class_method :resolve!
end
