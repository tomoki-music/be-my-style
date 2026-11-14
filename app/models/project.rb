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
  has_many :project_invitation_links, dependent: :destroy

  has_one_attached :project_image
  include ImagePositionable
  image_position_for :project_image

  # Business の画面で一覧に出すプロジェクト(所属コミュニティがそのドメインのもの)。
  scope :in_domain, ->(domain) { joins(:community).where(communities: { domain_id: domain&.id }) }

  # 新しく更新されたものから。同時刻は新しく作られた順にして並びを安定させる。
  scope :recently_updated, -> { order(updated_at: :desc, id: :desc) }

  # 公開範囲。既存のプロジェクトは通常公開。
  #   listed   通常公開 : 一覧・検索に出す。閲覧・参加申請の条件は BusinessAccess(親コミュニティの参加者が前提)
  #   unlisted 限定公開 : 一覧・検索(listed スコープを通す画面)に出さないだけで、条件は通常公開と同じ
  #   private  プライベート : 招待制。一覧には参加済みの本人にだけ出し、検索・通知には出さない。
  #                          詳細・スレッド・投稿・メンバー・添付は参加者と管理者だけ。
  #                          参加は招待リンク(ProjectInvitationLink)からだけで、親コミュニティへの所属は求めない
  enum visibility: { listed: 0, unlisted: 1, private: 2 }, _prefix: :visibility

  # 誰にでも一覧・検索に出してよいプロジェクト(通常公開)。管理画面の一覧には限定公開・プライベートも出す。
  scope :listed, -> { where(visibility: visibilities[:listed]) }

  # customer が参加済みのプライベートプロジェクト(BusinessAccess#business_project_approved_member? と同じ条件)。
  # 参加の行があり、プロジェクト・親コミュニティのどちらでもアクセス停止されていないこと。
  # システム管理者・オーナーでも、参加していなければ含めない(管理画面から開く)。
  scope :private_joined_by, lambda { |customer|
    next where(id: []) if customer.blank?

    where(visibility: visibilities[:private])
      .where(id: customer.project_members.select(:project_id))
      .where.not(id: customer.project_access_suspensions.select(:project_id))
      .where.not(community_id: customer.community_access_suspensions.select(:community_id))
  }

  # customer の一覧に出すプロジェクト: 通常公開 + 本人が参加済みのプライベート。限定公開は出さない。
  scope :listed_for, ->(customer) { listed.or(private_joined_by(customer)) }

  # スレッドを作成できる人。判定は BusinessAccess#can_create_project_thread?。既存・新規とも既定は管理者・オーナーのみ。
  # 既存スレッドの閲覧・返信の条件(プロジェクトの参加者)はこの設定に関係しない。
  enum thread_creation_policy: { owners_only: 0, managers: 1, all_members: 2 }, _prefix: :thread_creation

  # 参加方式。既存プロジェクトは移行で自動承認、新規作成の既定は手動承認。
  enum join_approval_mode: { manual: 0, auto: 1 }, _prefix: :join

  # どんな話題・活動のプロジェクトかを1行で伝える任意項目。前後の空白は落とし、空欄は未設定(NULL)として保存する。
  THEME_MAX_LENGTH = 100

  # goal(目標)・deadline(締切)は入力・表示・参加判定のいずれにも使わない。列とデータは残している。

  before_validation :normalize_theme
  validates :theme, length: { maximum: THEME_MAX_LENGTH }

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

  # プロジェクトの内部を閲覧できる人(参加資格のあるメンバー + 管理者)。通知・メールの宛先に使う。
  def accessible_customers
    ids = qualified_project_members.pluck(:customer_id)
    ids << customer_id if customer_id && community.community_customers.exists?(customer_id: customer_id)
    ids.concat(community.community_owners.pluck(:customer_id))
    ids << community.owner_id if community.owner_id.present?

    Customer.active.where(id: ids.uniq)
  end

  # スレッド投稿の通知先。判定は BusinessAccess#business_project_notification_recipient?(1人ずつ同じ条件で確認する)。
  def thread_post_notification_recipients(except: nil)
    ids = project_members.pluck(:customer_id)
    ids << customer_id if customer_id
    candidates = Customer.active.includes(:business_notification_setting).where(id: ids.uniq)
    candidates = candidates.where.not(id: except.id) if except

    candidates.to_a.select { |customer| customer.business_project_notification_recipient?(self) }
  end

  # メンバー一覧の表示用。参加資格を失った人(旧データ)は表示しない。
  def participating_members
    active_members.where(id: qualified_project_members.select(:customer_id))
  end

  # 参加資格のあるメンバーの行(BusinessAccess#business_project_membership_qualified? と同じ条件)。
  # 通常・限定公開は親コミュニティの承認済み参加者、プライベートは親コミュニティでアクセス停止されていない人。
  def qualified_project_members
    if visibility_private?
      project_members.where.not(customer_id: community.community_access_suspensions.select(:customer_id))
    else
      project_members.where(customer_id: community.community_customers.select(:customer_id))
    end
  end

  private

  # 1行の項目なので、改行や連続した空白は1つの空白にまとめる。
  def normalize_theme
    self.theme = theme.to_s.squish.presence
  end

  def create_default_thread
    ProjectThread.general_for!(self)
  end
end
