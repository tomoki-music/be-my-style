class Admin::CustomersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_customer, only: [:approval, :purge]

  def edit
    @customer = Customer.find(params[:id])
  end

  def update
    @customer = Customer.find(params[:id])
    @customer.skip_reconfirmation!
    if @customer.update_without_password(customer_params)
      redirect_to admin_homes_top_path, notice: "会員情報を更新しました。"
    else
      render :edit
    end
  end

  def approval
    if @customer.update(confirmed_at: Time.now)
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
    @customer = Customer.find(params[:customer_id])
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :email,
      :part,
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
      :password,
      :password_confirmation,
      :is_deleted,
      :is_owner,
      community_ids: [],
      community_owners_attributes: [:id, :community_id, :_destroy]
    )
  end

end
