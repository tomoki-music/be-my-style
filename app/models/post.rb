class Post < ApplicationRecord
  belongs_to :customer
  has_one_attached :post_image

  has_many :likes, dependent: :destroy
  has_many :messages, dependent: :destroy

  belongs_to :project, optional: true

  acts_as_taggable_on :tags

  enum category: {
    business_consultation: 0,
    learning: 1,
    project_recruitment: 2,
    member_recruitment: 3,
    free_post: 4
  }

  validates :body, presence: true

  # ビジネス
  def tag_list
    tags.to_s.split(" ")
  end

  def create_notification_like!(current_customer)

    temp = Notification.where(
      visitor_id: current_customer.id,
      visited_id: customer_id,
      action: "like"
    )

    if temp.blank?
      notification = current_customer.active_notifications.new(
        visited_id: customer_id,
        action: "like"
      )

      notification.save if notification.valid?
    end

  end

  def create_notification_message!(current_customer)

    temp = Notification.where(
      visitor_id: current_customer.id,
      visited_id: customer_id,
      action: "message"
    )

    if temp.blank?
      notification = current_customer.active_notifications.new(
        visited_id: customer_id,
        action: "message"
      )

      notification.save if notification.valid?
    end

  end

end
