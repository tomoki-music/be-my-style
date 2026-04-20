class Business::CustomersController < ApplicationController
  before_action :set_customer
  before_action :ensure_correct_customer, only: [:edit, :update]

  def show
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to business_customer_path(@customer), notice: "更新しました"
    else
      render :edit
    end
  rescue ActiveRecord::RecordInvalid
    render :edit
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def ensure_correct_customer
    unless @customer == current_customer
      redirect_to business_root_path, alert: "権限がありません"
    end
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :introduction,
      :profile_image,
      :job,
      :skills,
      :achievements,
      :url,
      part_ids: [],
      genre_ids: []
    )
  end

end
