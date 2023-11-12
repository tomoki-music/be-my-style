class Admin::HomesController < ApplicationController
  def top
    @customers = Customer.all
  end

  def confirmation
    customer = Customer.find(params[:customer_id])
    if customer.update(confirmed_at: Time.now)
      redirect_to admin_homes_top_path, notice: "メール承認の更新が完了しました!"
    else
      render "top"
    end
  end
end
