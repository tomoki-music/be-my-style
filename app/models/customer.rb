class Customer < ApplicationRecord
  MONTHLY_SESSION_CREDIT_AMOUNT = 1500

  PLAN_OPTIONS = [
    ["free", "free"],
    ["light", "light"],
    ["core", "core"],
    ["premium", "premium"]
  ].freeze

  FEATURE_RULES = {
    music_direct_chat: %w[light core premium],
    music_community_chat: %w[light core premium],
    music_activity_create: %w[light core premium],
    music_event_create: %w[core premium],
    music_community_mail: %w[premium],
    business_post_create: %w[light core premium],
    business_community_post_create: %w[light core premium],
    business_project_create: %w[core premium],
    business_community_create: %w[premium]
  }.freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to :prefecture

  has_one_attached :profile_image
  has_many :customer_domains
  has_many :domains, through: :customer_domains
  has_one :subscription

  attr_accessor :domain_name

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
  has_many :events, dependent: :destroy
  has_many :song_customers, dependent: :destroy
  has_many :songs, through: :song_customers, dependent: :destroy
  has_many :join_part_customers, dependent: :destroy
  has_many :join_parts, through: :join_part_customers, dependent: :destroy
  has_many :requests, dependent: :destroy

  has_many :community_owners, dependent: :destroy
  has_many :owned_communities, through: :community_owners, source: :community
  accepts_nested_attributes_for :community_owners, allow_destroy: true

  has_one :member_profile, dependent: :destroy
  accepts_nested_attributes_for :member_profile

  validates :name, presence: true, length: {maximum: 20}
  validates :email, uniqueness: true, presence: true
  # validates :customer_parts, presence: true

  # business
  has_many :posts, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :messages, dependent: :destroy

  has_many :community_posts

  has_many :projects, dependent: :destroy
  has_many :project_members, dependent: :destroy
  has_many :joined_projects, through: :project_members, source: :project

  # ストライプ（権限制御）
  def active_subscription
    subscription&.status == "active" ? subscription : nil
  end

  def plan
    active_subscription&.plan || "free"
  end

  def subscribed?
    active_subscription.present?
  end

  def paid_plan?
    plan != "free"
  end

  def subscription_plan
    plan
  end

  def subscription_status
    active_subscription&.status || subscription&.status || "free"
  end

  def stripe_managed_subscription?
    subscription&.stripe_customer_id.present? && subscription&.stripe_subscription_id.present?
  end

  def stale_subscription?
    subscribed? && !stripe_managed_subscription?
  end

  def clear_stale_subscription!
    return unless stale_subscription?

    subscription.update!(
      status: "canceled",
      plan: nil,
      stripe_customer_id: nil,
      stripe_subscription_id: nil
    )
  end

  def plan_badge_label
    plan.to_s.upcase
  end

  def session_credit_amount
    MONTHLY_SESSION_CREDIT_AMOUNT
  end

  def session_credit_available_for?(event)
    return false unless paid_plan?

    monthly_credited_participation_scope(event).none?
  end

  def session_credit_amount_for(event)
    return 0 unless session_credit_available_for?(event)

    [event.entrance_fee.to_i, session_credit_amount].min
  end

  def light?
    plan == "light"
  end

  def core?
    %w[core premium].include?(plan)
  end

  def premium?
    plan == "premium"
  end

  def has_feature?(feature_key)
    return true if admin?

    allowed_plans = FEATURE_RULES[feature_key.to_sym]
    return false if allowed_plans.blank?

    allowed_plans.include?(plan)
  end

  def self.subscription_plan_options
    PLAN_OPTIONS
  end

  def sync_subscription_plan!(next_plan)
    normalized_plan = next_plan.presence || "free"

    if normalized_plan == "free"
      subscription&.update!(status: "canceled", plan: nil)
      return
    end

    record = subscription || build_subscription
    record.plan = normalized_plan
    record.status = "active"
    record.save!
  end

  private

  def monthly_credited_participation_scope(event)
    join_part_customers
      .with_session_credit
      .joins(join_part: { song: :event })
      .where(events: { event_start_time: event.event_start_time.in_time_zone.all_month })
  end

  public

  # ドメイン管理
  def has_domain?(name)
    domains.exists?(name: name)
  end
  
  def music_user?
    domains.exists?(name: "music")
  end

  def business_user?
    domains.exists?(name: "business")
  end

  # 汎用型（ビジネス・音楽etc）
  def can_manage_community?(community)
    return true if admin?
    return false if community.blank?
    return true if community.owner_id == id
    return true if community_owner_of?(community)
    false
  end

  def community_owner_of?(community)
    owned_communities.exists?(id: community.id)
  end

  def manageable_communities
    owned_ids = owned_communities.select(:id)
    Community.where(owner_id: id).or(Community.where(id: owned_ids)).distinct
  end

  # 退会機能
  def active_for_authentication?
    return true if is_owner == 1
    super && !is_deleted
  end

  def inactive_message
    !is_deleted ? super : :deleted_account
  end

  enum sex: {
    gender_private: 0,
    male: 1,
    female: 2,
    others: 3,
  }, _prefix: true

  enum activity_stance: {
    beginner: 0,
    mypace: 1,
    tightly: 2,
  }, _prefix: true

  enum is_owner: { general: 0, admin: 1, community_owner: 2 }

  def self.is_owners_i18n
    is_owners.keys.index_with { |k| I18n.t("activerecord.attributes.customer.is_owner.#{k}") }
  end
  
  def available_communities_for_event
    if admin?
      Community.all
    elsif manageable_communities.exists?
      manageable_communities
    else
      communities
    end
  end

  def eligible_to_create_event_for?(community = nil)
    return true if admin?
    return can_manage_community?(community) if community.present?

    manageable_communities.exists?
  end

  def can_create_event?(community = nil)
    return true if admin?
    return true if eligible_to_create_event_for?(community)
    return false unless has_feature?(:music_event_create)
    return communities.exists? if community.blank?

    communities.exists?(id: community.id)
  end

  def can_create_project_for?(community)
    return true if admin?
    return true if can_manage_community?(community)
    return false unless has_feature?(:business_project_create)

    community.present? && communities.exists?(id: community.id)
  end

  def can_edit_event?(event)
    return true if admin?
    return true if event.customer_id == id
    return false unless event.community

    can_manage_community?(event.community)
  end

  def update_without_password(params, *options)
    params.delete(:password)
    params.delete(:password_confirmation)
    
    assign_attributes(params)
    save(validate: true)
  end
  

  def update_password(params, *options)
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end
 
    result = update(params, *options)
    clean_up_passwords
    result
  end

  def follow(customer_id)
    return if id == customer_id
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

  def business_notification_follow(current_customer)
    return if current_customer.id == id

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
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'comment',
      activity_id: activity_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_request_msg(current_customer, event_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'request-msg',
      event_id: event_id,
    )
    notification.save if notification.valid?
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

  def create_notification_activity_for_community(current_customer, activity_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'activity_for_community',
      activity_id: activity_id,
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

  def create_notification_event_for_community(current_customer, event_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'event_for_community',
      event_id: event_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_event_for_follow(current_customer, event_id)
    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'event_for_follow',
      event_id: event_id,
    )
    notification.save if notification.valid?
  end

  def create_notification_join_event(current_customer, event_id)
    temp = Notification.where(["visitor_id = ? and visited_id = ? and action = ? and event_id = ?",current_customer.id, id, 'join_event', event_id])
    if temp.blank?
      notification = current_customer.active_notifications.new(
        visited_id: id,
        action: 'join_event',
        event_id: event_id,
      )
      notification.save if notification.valid?
    end
  end

  # ビジネス（NAKAMA）
  def business_notification_request(current_customer, community_id)
    return if current_customer.id == id

    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'request',
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def business_notification_accept(current_customer, community_id)
    return if current_customer.id == id

    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'accept',
      community_id: community_id,
    )
    notification.save if notification.valid?
  end

  def business_notification_project_created(current_customer, project)
    return if current_customer.id == id

    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'project_created',
      community_id: project.community_id,
      project_id: project.id
    )
    notification.save if notification.valid?
  end

  def business_notification_project_joined(current_customer, project)
    return if current_customer.id == id

    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'project_joined',
      community_id: project.community_id,
      project_id: project.id
    )
    notification.save if notification.valid?
  end

  def business_notification_project_message(current_customer, project)
    return if current_customer.id == id

    notification = current_customer.active_notifications.new(
      visited_id: id,
      action: 'project_message',
      community_id: project.community_id,
      project_id: project.id
    )
    notification.save if notification.valid?
  end

end
