class ProjectChat < ApplicationRecord
  include BusinessChatContent

  belongs_to :project
  belongs_to :customer
  # 移行前の旧コードが書き込んだ行だけ NULL になり得る(rails business_project_threads:backfill で紐づける)。
  belongs_to :project_thread, optional: true

  # スレッド指定の無い作成(旧導線)は「全体トーク」へ入れる。
  before_validation :assign_default_thread, on: :create
  validates :project_thread, presence: true, on: :create
  validate :project_thread_in_same_project

  after_create_commit :touch_thread_last_posted_at

  private

  def assign_default_thread
    self.project_thread ||= ProjectThread.default_for(project) if project
  end

  def project_thread_in_same_project
    return if project_thread.blank? || project_thread.project_id == project_id

    errors.add(:base, "スレッドが見つかりません")
  end

  def touch_thread_last_posted_at
    project_thread&.update_column(:last_posted_at, created_at)
  end
end
