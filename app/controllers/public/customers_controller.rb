class Public::CustomersController < ApplicationController
  before_action :authenticate_customer!
  
  def index
    @customers = Customer.page(params[:page]).per(8)
  end

  def show
  end

  def edit
  end

  def update
  end
end
