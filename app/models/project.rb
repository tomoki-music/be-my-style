class Project < ApplicationRecord
  belongs_to :community
  # 作成者の会員データが完全削除されると NULL になる(プロジェクトと会話は残し、運営者が管理する)。
  belongs_to :customer, optional: true

  has_many :project_members, dependent: :destroy
  has_many :members, through: :project_members, source: :customer

  # project_chats はスレッドより先に消す(project_chats.project_thread_id の外部キー)。
  has_many :project_chats, dependent: :destroy
  has_many :project_threads, dependent: :destroy
  has_many :project_join_requests, dependent: :destroy
  has_many :project_access_suspensions, dependent: :destroy

  has_one_attached :project_image

  # Business の画面で一覧に出すプロジェクト(所属コミュニティがそのドメインのもの)。
  scope :in_domain, ->(domain) { joins(:community).where(communities: { domain_id: domain&.id }) }

  # 新しく更新されたものから。同時刻は新しく作られた順にして並びを安定させる。
  scope :recently_updated, -> { order(updated_at: :desc, id: :desc) }

  # 参加方式。既存プロジェクトは移行で自動承認、新規作成の既定は手動承認。
  enum join_approval_mode: { manual: 0, auto: 1 }, _prefix: :join

  after_create :create_default_thread

  enum status: {
    recruiting: 0,
    active: 1,
    completed: 2
  }

  # 一般・公開画面で退会ユーザーを除外したプロジェクトメンバーを扱う際に使う。
  # ProjectMemberレコード自体は削除しないため、ここでの絞り込みは表示専用。
  def active_members
    members.active
  end

  # プロジェクトの内部を閲覧できる人(コミュニティ参加資格のあるメンバー + 管理者)。通知・メールの宛先に使う。
  def accessible_customers
    community_member_ids = community.community_customers.select(:customer_id)
    ids = project_members.where(customer_id: community_member_ids).pluck(:customer_id)
    ids << customer_id if customer_id && community.community_customers.exists?(customer_id: customer_id)
    ids.concat(community.community_owners.pluck(:customer_id))
    ids << community.owner_id if community.owner_id.present?

    Customer.active.where(id: ids.uniq)
  end

  # メンバー一覧の表示用。コミュニティ参加資格を失った人(旧データ)は表示しない。
  def participating_members
    active_members.where(id: community.community_customers.select(:customer_id))
  end

  def deadline_passed?
    deadline.present? && deadline < Time.current
  end

  private

  def create_default_thread
    ProjectThread.general_for!(self)
  end
end
