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
  has_many :customer_parts, dependent: :destroy
  has_many :parts, through: :customer_parts, dependent: :destroy
  has_many :customer_genres, dependent: :destroy
  has_many :genres, through: :customer_genres, dependent: :destroy
  has_many :relationships, class_name: "Relationship", foreign_key: "follower_id", dependent: :destroy
  has_many :reverse_of_relationships, class_name: "Relationship", foreign_key: "followed_id", dependent: :destroy
  has_many :followings, through: :relationships, source: :followed, dependent: :destroy
  has_many :followers, through: :reverse_of_relationships, source: :follower, dependent: :destroy
  has_many :active_notifications, class_name: 'Notification', foreign_key: 'visitor_id', dependent: :destroy
  has_many :passive_notifications, class_name: 'Notification', foreign_key: 'visited_id', dependent: :destroy
  has_many :chat_room_customers, dependent: :destroy
  has_many :chat_rooms, through: :chat_room_customers, dependent: :destroy
  has_many :communities, through: :chat_room_customers, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
  has_many :community_customers, dependent: :destroy
  has_many :communities, through: :community_customers, dependent: :destroy
  has_many :permits, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :name, presence: true, length: {maximum: 20}
  validates :email, uniqueness: true, presence: true
  validates :customer_parts, presence: true

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
        action: 'follow',
      )
      notification.save if notification.valid?
    end
  end

  def create_notification_favorite(current_customer, activity_id)
    temp = Notification.where(["visitor_id = ? and visited_id = ? and action = ? and activity_id = ?",current_customer.id, id, 'favorite', activity_id])
    if temp.blank?
      notification = current_customer.active_notifications.new(
        visited_id: id,
        action: 'favorite',
        activity_id: activity_id,
      )
      notification.save if notification.valid?
    end
  end

  def create_notification_comment(current_customer, activity_id)
    temp = Notification.where(["visitor_id = ? and visited_id = ? and action = ? and activity_id = ?",current_customer.id, id, 'comment', activity_id])
    if temp.blank?
      notification = current_customer.active_notifications.new(
        visited_id: id,
        action: 'comment',
        activity_id: activity_id,
      )
      notification.save if notification.valid?
    end
  end

  def create_notification_chat(current_customer)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'chat',
    )
    notification.save if notification.valid?
  end

  def create_notification_group_chat(current_customer, community_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'group_chat',
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_request(current_customer, community_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'request',
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_request_cancel(current_customer, community_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'request_cancel',
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_accept(current_customer, community_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'accept',
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_leave(current_customer, community_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'leave',
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_activity_for_community(current_customer, activity_id, community_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'activity_for_community',
      activity_id: activity_id,
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_activity_for_follow(current_customer, activity_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'activity_for_follow',
      activity_id: activity_id,
    )
    notification.save if notification.valid?
  end
end
