class Public::CustomersController < ApplicationController
  before_action :authenticate_customer!
  
  def index
    @customers = Customer.page(params[:page]).per(8)
  end

  def show
    @customer = Customer.find(params[:id])
  end

  def edit
    @customer = Customer.find(params[:id])
  end

  def update
  end
end
