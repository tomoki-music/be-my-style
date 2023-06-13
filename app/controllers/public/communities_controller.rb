class Public::CommunitiesController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:edit, :update]

  def index
    @communities = Community.all
  end

  def show
    @community = Community.find(params[:id])
  end

  def new
    @community = Community.new
  end

  def create
    @community = Community.new(community_params)
    @community.owner_id = current_customer.id
    if @community.save
      redirect_to public_communities_path
    else
      render 'new'
    end
  end

  def edit
  end

  def update
    if @community.update(community_params)
      redirect_to public_communities_path
    else
      render "edit"
    end
  end

  private

  def community_params
    params.require(:community).permit(:name, :introduction, :community_image)
  end

  def ensure_correct_customer
    @community = Community.find(params[:id])
    unless @community.owner_id == current_customer.id
      redirect_to public_communities_path
    end
  end
end
