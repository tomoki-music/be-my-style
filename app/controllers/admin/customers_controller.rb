class Admin::CustomersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_customer, only: [:approval, :purge]

  def index
    @customers = Customer.all
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
end
