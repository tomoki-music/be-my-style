class Project < ApplicationRecord
  belongs_to :community
  belongs_to :customer

  has_many :project_members, dependent: :destroy
  has_many :members, through: :project_members, source: :customer

  has_many :project_chats, dependent: :destroy

  has_one_attached :project_image

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
