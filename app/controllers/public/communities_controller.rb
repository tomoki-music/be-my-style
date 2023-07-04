class Public::CommunitiesController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:edit, :update, :destroy]
  before_action :authority_create_community, only: [:new, :create]

  def index
    @communities = Community.all
  end

  def show
    @community = Community.find(params[:id])
    @owner = Customer.find_by(id: @community.owner_id)
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
    redirect_to public_communities_path, alert: "コミュニティを削除しました!"
  end

  def leave
    @community = Community.find(params[:community_id])
    @community.customers.delete(current_customer)
    redirect_to public_communities_path, alert: "コミュニティを退会しました!"
  end

  def new_mail
    @community = Community.find(params[:community_id])
  end

  def send_mail
    @community = Community.find(params[:community_id])
    community_customers = @community.customers
    @mail_title = params[:mail_title]
    @mail_content = params[:mail_content]
    ContactMailer.send_mail(@mail_title, @mail_content,community_customers).deliver
  end

  private

  def community_params
    params.require(:community).permit(
      :name,
      :activity_stance,
      :favorite_artist1,
      :favorite_artist2,
      :favorite_artist3,
      :favorite_artist4,
      :favorite_artist5,
      :introduction,
      :community_image,
      :prefecture_id,
      :url,
      genre_ids: [],
    )
  end

  def ensure_correct_customer
    @community = Community.find(params[:id])
    unless @community.owner_id == current_customer.id
      redirect_to public_communities_path, alert: "編集・削除する権限がありません。"
    end
  end

  def authority_create_community
    unless current_customer.id == 1
      redirect_to public_communities_path, alert: "コミュニティを作成する権限がありません。"
    end
  end
end
