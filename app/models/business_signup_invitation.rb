# 招待用URLを開いて新規登録した人の招待先(コミュニティ・プロジェクトの詳細画面)。
# 記録・取り出しは Business::SignupInvitations::Remember / Take を使う。
class BusinessSignupInvitation < ApplicationRecord
  # 登録から確認メール(有効期限は Devise の confirm_within)・オンボーディングまでを見込んだ期限。
  TTL = 7.days
  # オンボーディング後、招待先のプロジェクトの親コミュニティへの参加(承認待ちを含む)を待つ間の期限。
  AWAITING_TTL = 30.days
  TARGET_TYPES = %w[Community Project].freeze

  belongs_to :customer

  validates :customer_id, uniqueness: true
  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :target_id, :expires_at, presence: true

  def expired?(now = Time.current)
    expires_at <= now
  end
end
