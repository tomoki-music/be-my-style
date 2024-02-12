class Public::CustomersController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:update, :edit]
  before_action :set_customer, only: [:show, :edit, :update, :edit_password, :update_password]
  before_action :check_same_community, only: [:show]
  
  def index
  end

  def show
    got_follow_customers_ids = Relationship.where(followed_id: current_customer.id).pluck(:follower_id)
    @mathing_customers = Relationship.where(followed_id: got_follow_customers_ids, follower_id: current_customer.id).where.not(followed_id: current_customer.id).map do |follow|
      follow.followed.id
    end
  end

  def edit
  end

  def update
    if @customer.update_without_password(customer_params)
      redirect_to public_customer_path(@customer), notice: "プロフィールの更新が完了しました!"
    else
      render "edit"
    end
  end

  def edit_password
  end

  def update_password
    if password_set?
      @customer.update_password(customer_params) 
      flash[:notice] = "パスワードは正しく更新されました。"
      redirect_to root_url
    else
      @customer.errors.add(:password, "パスワードに不備があります。")
      render "edit_password"
    end
  end

  private

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
      part_ids: [],
      genre_ids: [],
    )
  end

  def ensure_correct_customer
    @customer = Customer.find(params[:id])
    unless @customer == current_customer
      redirect_to public_customer_path(current_customer)
    end
  end

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def check_same_community
    @visited_customer = Customer.find(params[:id])
    return if current_customer == @visited_customer || current_customer == Customer.find(1)
    visited_customer_community_ids = ChatRoomCustomer.where(customer_id: @visited_customer.id).pluck(:community_id)

    check_same_community_ids = ChatRoomCustomer.where(customer_id: current_customer.id, community_id: visited_customer_community_ids).map do |check|
      check.id
    end
    unless check_same_community_ids.present?
      redirect_to public_communities_path, alert: "メンバー詳細は同じコミュニティメンバーのみ閲覧できます。"
    end
  end

  def password_set?
    customer_params[:password].present? && customer_params[:password_confirmation].present? ?
    true : false
  end
end
