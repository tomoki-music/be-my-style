class Admin::HomesController < ApplicationController
  before_action :authenticate_admin!
  
  def top
    @customers = Customer.all
  end

end
