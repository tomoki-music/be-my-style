# プライベート(招待制)プロジェクトの招待リンク。発行・無効化はシステム管理者と親コミュニティのオーナー本人だけ
# (BusinessAccess#can_manage_business_project_privacy?)。
#
# - トークンは推測できない乱数(32バイト)。DB にはダイジェストだけを保存し、リンクは発行直後の画面にだけ表示する。
# - 有効なリンクはプロジェクトごとに1本。再発行すると、それまでのリンクは無効化される。
# - 期限内なら何人でも使える(used_count は表示用の参加人数)。
# - プライベートでなくなったプロジェクトのリンクは使えない(公開範囲の変更時に無効化もする)。
class ProjectInvitationLink < ApplicationRecord
  # 発行時に選べる有効期限(日数)。既定は7日。
  EXPIRY_DAYS = [1, 7, 30].freeze
  DEFAULT_EXPIRY_DAYS = 7
  TOKEN_BYTES = 32
  # urlsafe_base64(32) は43文字。これより長い値は照合せずに捨てる。
  TOKEN_MAX_LENGTH = 100

  belongs_to :project
  belongs_to :created_by, class_name: "Customer", optional: true

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :not_revoked, -> { where(revoked_at: nil) }

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # 受け取ったトークンに一致するリンク。空・長すぎる値は照合しない。期限・無効化の確認は status で行う。
  def self.find_by_token(token)
    token = token.to_s
    return if token.blank? || token.length > TOKEN_MAX_LENGTH

    find_by(token_digest: digest(token))
  end

  # それまでのリンクを無効化して、新しいリンクを発行する。戻り値は [リンク, トークン]。
  # トークンはこの戻り値でだけ受け取れる(保存しない・ログに出さない)。
  def self.issue!(project:, created_by:, expiry_days: DEFAULT_EXPIRY_DAYS, now: Time.current)
    expiry_days = DEFAULT_EXPIRY_DAYS unless EXPIRY_DAYS.include?(expiry_days)
    token = SecureRandom.urlsafe_base64(TOKEN_BYTES)

    link = project.with_lock do
      revoke_all!(project, now: now)
      create!(project: project, created_by: created_by, token_digest: digest(token), expires_at: now + expiry_days.days)
    end
    [link, token]
  end

  def self.revoke_all!(project, now: Time.current)
    project.project_invitation_links.not_revoked.update_all(revoked_at: now, updated_at: now)
  end

  # :active / :revoked(無効化・再発行済み) / :expired(期限切れ) / :unavailable(プロジェクトがプライベートでない)
  def status(now = Time.current)
    return :revoked if revoked_at.present?
    return :unavailable unless project&.visibility_private?
    return :expired if expires_at <= now

    :active
  end

  def usable?(now = Time.current)
    status(now) == :active
  end

  def record_use!(now = Time.current)
    self.class.where(id: id).update_all(["used_count = used_count + 1, last_used_at = ?, updated_at = ?", now, now])
  end
end
