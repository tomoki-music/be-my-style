class Public::CustomersController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:update, :edit]
  before_action :set_customer, only: [:show, :edit, :update]
  
  def index
    @customers = params[:part_id].present? ? Part.find(params[:part_id]).customers.page(params[:page]).per(8) : Customer.page(params[:page]).per(8)
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
    if @customer.update(customer_params)
      redirect_to public_customer_path(@customer), notice: "プロフィールの更新が完了しました!"
    else
      render "edit"
    end
  end

  private

  def customer_params
    params.require(:customer).permit(
      :name,
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
end
