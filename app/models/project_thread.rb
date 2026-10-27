# プロジェクト内の話題ごとの会話(スレッド)。閲覧・投稿の権限は所属プロジェクトから継承する
# (スレッド単位の個別権限は持たない。判定は BusinessAccess)。
class ProjectThread < ApplicationRecord
  DEFAULT_TITLE = "全体トーク".freeze
  TITLE_MAX_LENGTH = 50
  DESCRIPTION_MAX_LENGTH = 1000

  belongs_to :project
  # 作成者の会員データが完全削除されると NULL になる(スレッドと会話は残す)。
  belongs_to :customer, optional: true

  has_many :project_chats, dependent: :destroy

  # 「全体トーク」は作成者のいないプロジェクトでも自動で補完するため、作成者なしを許す。
  validates :customer, presence: true, on: :create, unless: :general?
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }

  before_validation :set_last_posted_at, on: :create

  scope :recently_active, -> { order(last_posted_at: :desc, id: :desc) }

  # 「全体トーク」(general = true)。旧画面からの投稿(スレッド指定なし)・旧コードが書き込んだ投稿の送り先。
  # ほかのスレッドへは決して振り分けない(全体トークが無いときに別の話題の会話へ混ぜないため)。
  def self.default_for(project)
    project.project_threads.find_by(general: true)
  end

  # 全体トークを返す。無ければ作る。(project_id, general) の一意制約があるため、同時に呼ばれても1つだけになる。
  def self.general_for!(project)
    default_for(project) || project.project_threads.create!(general: true, title: DEFAULT_TITLE, customer: project.customer)
  rescue ActiveRecord::RecordNotUnique
    project.project_threads.find_by!(general: true)
  end

  private

  def set_last_posted_at
    self.last_posted_at ||= Time.current
  end
end
