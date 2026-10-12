class Project < ApplicationRecord
  belongs_to :community
  belongs_to :customer

  has_many :project_members, dependent: :destroy
  has_many :members, through: :project_members, source: :customer

  has_many :project_chats, dependent: :destroy

  has_one_attached :project_image

  # Business の画面で一覧に出すプロジェクト(所属コミュニティがそのドメインのもの)。
  scope :in_domain, ->(domain) { joins(:community).where(communities: { domain_id: domain&.id }) }

  # 新しく更新されたものから。同時刻は新しく作られた順にして並びを安定させる。
  scope :recently_updated, -> { order(updated_at: :desc, id: :desc) }

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
end
