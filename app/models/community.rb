class Community < ApplicationRecord
  EVENT_CREATION_REQUIRED_PLANS = %w[core premium].freeze

  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to :prefecture

  has_many :community_customers, dependent: :destroy
  has_many :customers, through: :community_customers, dependent: :destroy
  has_many :community_owners, dependent: :destroy
  has_many :owners, through: :community_owners, source: :customer
  has_many :community_event_editors, dependent: :destroy
  has_many :event_editors, through: :community_event_editors, source: :customer
  has_many :permits, dependent: :destroy
  has_many :community_genres, dependent: :destroy
  has_many :genres, through: :community_genres, dependent: :destroy
  has_many :chat_room_customers, dependent: :destroy
  has_many :chat_rooms, through: :chat_room_customers, dependent: :destroy
  has_many :chat_room_members, through: :chat_room_customers, source: :customer
  has_many :chat_messages, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :song_templates, dependent: :destroy
  belongs_to :owner, class_name: "Customer", optional: true

# NOTE: 将来的に多対多対応するために残しているが、
# 現在はdomain_idのみ使用
  # has_many :community_domains, dependent: :destroy
  # has_many :domains, through: :community_domains
  belongs_to :domain

  has_many :community_posts, dependent: :destroy
  has_many :projects, dependent: :destroy
  
  has_many :members, through: :community_customers, source: :customer

  has_one_attached :community_image

  validates :name, presence: true
  validates :name, length: { maximum: 30 }
  validates :introduction, presence: true
  validates :required_plan_for_event_creation, presence: true, inclusion: { in: EVENT_CREATION_REQUIRED_PLANS }

  enum activity_stance: {
    beginner: 0,
    mypace: 1,
    tightly: 2,
  }, _prefix: true

  def premium_event_creation_required?
    required_plan_for_event_creation == "premium"
  end

  # 一般・公開画面で退会ユーザーを除外したメンバーを扱う際に使う。
  # CommunityCustomerレコード自体は削除しないため、ここでの絞り込みは表示専用。
  def active_customers
    customers.active
  end

end
