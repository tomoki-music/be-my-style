class Customer < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to :prefecture

  enum sex: {
    gender_private: 0,
    male: 1,
    female: 2,
    others: 3,
  }, _prefix: true

  enum activity_stance: {
    beginer: 0,
    mypace: 1,
    tightly: 2,
  }, _prefix: true

  has_one_attached :profile_image
  has_many :addresses, dependent: :destroy
  has_many :carts, dependent: :destroy
  has_many :customer_parts, dependent: :destroy
  has_many :parts, through: :customer_parts
  has_many :customer_genres, dependent: :destroy
  has_many :genres, through: :customer_genres
  has_many :relationships, class_name: "Relationship", foreign_key: "follower_id", dependent: :destroy
  has_many :reverse_of_relationships, class_name: "Relationship", foreign_key: "followed_id", dependent: :destroy
  has_many :followings, through: :relationships, source: :followed
  has_many :followers, through: :reverse_of_relationships, source: :follower
  has_many :active_notifications, class_name: 'Notification', foreign_key: 'visitor_id', dependent: :destroy
  has_many :passive_notifications, class_name: 'Notification', foreign_key: 'visited_id', dependent: :destroy

  validates :name, presence: true, length: {maximum: 20}
  validates :email, uniqueness: true, presence: true

  def follow(customer_id)
    relationships.create(followed_id: customer_id)
  end
  def unfollow(customer_id)
    relationships.find_by(followed_id: customer_id).destroy
  end
  def following?(customer)
    followings.include?(customer)
  end

  def create_notification_follow(current_customer)
    temp = Notification.where(["visitor_id = ? and visited_id = ? and action = ? ",current_customer.id, id, 'follow'])
    if temp.blank?
      notification = current_customer.active_notifications.new(
        visited_id: id,
        action: 'follow'
      )
      notification.save if notification.valid?
    end
  end
end
