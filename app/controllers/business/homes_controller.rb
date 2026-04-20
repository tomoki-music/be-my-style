class Business::HomesController < ApplicationController
  skip_before_action :authenticate_customer!, only: [:top]

  def top
  end
end
