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
  has_many :customers, through: :chat_room_customers, dependent: :destroy
  has_many :chat_messages, dependent: :destroy

  has_one_attached :community_image

  validates :name, presence: true
  validates :introduction, presence: true

  enum activity_stance: {
    beginer: 0,
    mypace: 1,
    tightly: 2,
  }, _prefix: true
end
