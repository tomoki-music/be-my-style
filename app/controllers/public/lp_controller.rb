class Public::LpController < ApplicationController
  skip_before_action :authenticate_customer!, only: [:index, :singing]

  def index
  end

  def singing
  end
end
