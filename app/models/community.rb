class Community < ApplicationRecord
  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to :prefecture

  has_many :community_customers, dependent: :destroy
  has_many :customers, through: :community_customers, dependent: :destroy
  has_many :permits, dependent: :destroy
  has_many :community_genres, dependent: :destroy
  has_many :genres, through: :community_genres, dependent: :destroy
  has_many :chat_room_customers, dependent: :destroy
  has_many :chat_rooms, through: :chat_room_customers, dependent: :destroy
  has_many :chat_room_members, through: :chat_room_customers, source: :customer
  has_many :chat_messages, dependent: :destroy
  has_many :events, dependent: :destroy
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

  enum activity_stance: {
    beginner: 0,
    mypace: 1,
    tightly: 2,
  }, _prefix: true

  before_save :normalize_text

  private

  def normalize_text
    self.introduction = introduction.to_s
      .gsub(/\r\n?/, "\n")   # Windows改行 → 統一
      .gsub(/\u2028/, "\n")  # 謎改行 → 正常化
  end
end
