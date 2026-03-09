class Business::CustomersController < ApplicationController

  before_action :set_customer

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
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :introduction,
      :image
    )
  end

end
