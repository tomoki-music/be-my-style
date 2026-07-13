class Public::HomesController < ApplicationController
  skip_before_action :authenticate_customer!, only: [:top]

  def top
    render "public/homes/guest_top" unless customer_signed_in?
  end

  def about
  end
end
