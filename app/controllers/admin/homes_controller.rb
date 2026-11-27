class Admin::HomesController < ApplicationController
  before_action :authenticate_admin!
  
  def top
    @admin_notifications = current_admin
      .admin_notifications
      .includes(:customer)
      .order(created_at: :desc)
      .limit(30)
      .to_a
    @unchecked_admin_notifications_count = current_admin.admin_notifications.where(checked: false).count
    current_admin.admin_notifications.where(id: @admin_notifications.map(&:id), checked: false).update_all(checked: true)

    @customers = Customer
      .includes(:member_profile, :subscription, community_owners: :community, community_event_editors: :community)
      .with_attached_profile_image
      .references(:member_profile)

    @customers = AdminCustomers::ListFilter.call(@customers, params)

    @customers = @customers.to_a
    # 「条件に一致した人をすべて選択」用。表示中の行に限らず、条件に合う会員 ID をすべて渡す。
    @matching_customer_ids = AdminCustomers::ListFilter.call(Customer.all, params).order(:id).pluck(:id)

    # Community#owner_idは公開画面からのコミュニティ作成時にのみ設定され、
    # CommunityOwnerへは同期されないため、オーナー件数の算出にはこちらも合算する必要がある。
    @direct_owned_communities_by_customer_id =
      Community.where(owner_id: @customers.map(&:id)).group_by(&:owner_id)
  end

end
