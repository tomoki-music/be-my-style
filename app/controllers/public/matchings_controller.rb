class Public::MatchingsController < ApplicationController
  before_action :authenticate_customer!
  include MatchingIndex
  before_action :matching_index, only: [:index]

  def index
    @customer = Customer.find(current_customer.id)
  end
end
