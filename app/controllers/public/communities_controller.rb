class Public::CommunitiesController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:edit, :update, :destroy]

  def index
    @communities = Community.all
  end

  def show
    @community = Community.find(params[:id])
    @community_customers = params[:part_id].present? ? Kaminari.paginate_array(Part.find(params[:part_id]).customers.filter {|customer| customer.community_customers.where(community_id: @community.id).present? } ).page(params[:page]).per(6) : @community.customers.page(params[:page]).per(6)
  end

  def join
    @community = Community.find(params[:community_id])
    @community.customers << current_customer
    redirect_to  public_communities_path, notice: "コミュニティへ参加しました!"
  end

  def new
    @community = Community.new
  end

  def create
    @community = Community.new(community_params)
    @community.owner_id = current_customer.id
    @community.customers << current_customer
    if @community.save
      redirect_to public_communities_path, notice: "コミュニティを作成しました!"
    else
      render 'new'
    end
  end

  def edit
    @community = Community.find(params[:id])
  end

  def update
    if @community.update(community_params)
      redirect_to public_communities_path, notice: "コミュニティの編集が完了しました!"
    else
      render "edit"
    end
  end

  def destroy
    @community = Community.find(params[:id])
    @community.destroy
    redirect_to public_communities_path, notice: "コミュニティを削除しました!"
  end

  def leave
    @community = Community.find(params[:community_id])
    @community.customers.delete(current_customer)
    redirect_to public_communities_path, alert: "コミュニティを退会しました!"
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
