class Admin::CommunitiesController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_community, only: [:show, :edit, :update, :destroy]

  def index
    @communities = Community.includes(:owner, :genres).order(created_at: :desc)
  end

  def show
  end

  def new
    @community = Community.new
  end

  def create
    @community = Community.new(community_params)

    if @community.save
      sync_community_relationships!(@community)
      redirect_to admin_community_path(@community), notice: "コミュニティを登録しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @community.update(community_params)
      sync_community_relationships!(@community)
      redirect_to admin_community_path(@community), notice: "コミュニティを更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @community.destroy
    redirect_to admin_communities_path, alert: "コミュニティを削除しました。"
  end

  private

  def set_community
    @community = Community.find(params[:id])
  end

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
      :owner_id,
      :domain_id,
      genre_ids: []
    )
  end

  def sync_community_relationships!(community)
    owner = community.owner
    return if owner.blank?

    CommunityOwner.where(community_id: community.id).where.not(customer_id: owner.id).destroy_all
    CommunityOwner.find_or_create_by!(community_id: community.id, customer_id: owner.id)
    community.community_customers.find_or_create_by!(customer_id: owner.id)

    chat_room = community.chat_rooms.first || ChatRoom.create!
    ChatRoomCustomer.find_or_create_by!(
      community_id: community.id,
      customer_id: owner.id,
      chat_room_id: chat_room.id
    )
  end
end
