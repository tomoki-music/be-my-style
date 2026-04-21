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
      .includes(:member_profile, :subscription)
      .references(:member_profile)

    if params[:member_type].present?
      @customers = @customers.where(
        member_profiles: { suggested_member_type: params[:member_type] }
      )
    end

    if params[:music_experience_level].present?
      @customers = @customers.where(
        member_profiles: { music_experience_level: params[:music_experience_level] }
      )
    end

    if params[:engagement_style].present?
      @customers = @customers.where(
        member_profiles: { engagement_style: params[:engagement_style] }
      )
    end

    if params[:contact_preference].present?
      @customers = @customers.where(
        member_profiles: { contact_preference: params[:contact_preference] }
      )
    end
  end

end
