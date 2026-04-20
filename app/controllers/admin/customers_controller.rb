class Admin::CustomersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_customer, only: [:approval, :purge, :edit, :update]
  before_action :set_member_profile, only: [:edit, :update]

  def edit
    # @customer は before_action で取得済み
    # @member_profile も取得済み
  end

  def update
    @customer.skip_reconfirmation!

    ActiveRecord::Base.transaction do
      updated = @customer.update_without_password(customer_params.except(:subscription_plan))
      raise ActiveRecord::Rollback unless updated

      @customer.sync_subscription_plan!(customer_params[:subscription_plan])

      if params[:customer][:owned_community_ids]
        @customer.community_owners.destroy_all
        params[:customer][:owned_community_ids].reject(&:blank?).each do |community_id|
          @customer.community_owners.create!(community_id: community_id)
        end
      end

      redirect_to admin_homes_top_path, notice: "会員情報を更新しました。"
      return
    end

    render :edit
  rescue ActiveRecord::RecordInvalid
    render :edit
  end

  def approval
    if @customer.update(confirmed_at: Time.current)
      redirect_to admin_homes_top_path, notice: "メール承認の更新が完了しました!"
    else
      render "index"
    end
  end

  def purge
    if @customer.destroy
      redirect_to admin_homes_top_path, alert: "アカウントを完全削除しました!"
    else
      render "index"
    end
  end

  private

  def set_customer
    @customer = Customer.includes(:owned_communities).find(params[:id] || params[:customer_id])
  end

  def set_member_profile
    @member_profile = @customer.member_profile || @customer.build_member_profile
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :email,
      :sex,
      :birthday,
      :activity_stance,
      :favorite_artist1,
      :favorite_artist2,
      :favorite_artist3,
      :favorite_artist4,
      :favorite_artist5,
      :introduction,
      :profile_image,
      :prefecture_id,
      :url,
      :confirm_mail,
      :subscription_plan,
      :password,
      :password_confirmation,
      :is_deleted,
      :is_owner,
      owned_community_ids: [],
      community_owners_attributes: [:id, :community_id, :_destroy],

      member_profile_attributes: [
        :id,
        :entry_source,
        :join_reason,
        :want_to_do,
        :music_experience_level,
        :engagement_style,
        :suggested_member_type,
        :contact_preference,
        :admin_memo
      ]
    )
  end

end
