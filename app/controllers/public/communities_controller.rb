class Public::CommunitiesController < ApplicationController
  before_action :set_community, only: [:show, :edit, :update, :destroy, :leave, :new_mail, :send_mail, :permits]
  before_action :ensure_correct_customer, only: [:edit, :update, :destroy, :permits]
  before_action :check_mail, only: [:send_mail]
  before_action :admin_only!, only: [:new, :create, :destroy]

  def index
    @communities = Community
      .where(domain_id: @current_domain.id)
      .page(params[:page]).per(5)
  end

  def show
    @owner = @community.owner

    @community_customers =
      if params[:part_id].present?
        Kaminari.paginate_array(
          Part.find(params[:part_id]).customers.select do |customer|
            customer.community_customers.where(community_id: @community.id).exists?
          end
        ).page(params[:page]).per(3)
      else
        @community.customers.page(params[:page]).per(3)
      end
  end

  def new
    @community = Community.new
  end

  def create
    @community = Community.new(community_params)
    @community.owner_id = current_customer.id
    @community.domain_id = @current_domain.id

    if @community.save
      # 👇① コミュニティ参加させる（これ追加）
      CommunityCustomer.create!(
        community_id: @community.id,
        customer_id: current_customer.id
      )

      # 👇② チャットルーム作成
      chat_room = ChatRoom.create

      ChatRoomCustomer.create!(
        community_id: @community.id,
        customer_id: current_customer.id,
        chat_room_id: chat_room.id
      )

      redirect_to public_communities_path, notice: "コミュニティを作成しました!"
    else
      render 'new'
    end
  end

  def edit
  end

  def update
    if @community.update(community_params)
      redirect_to public_community_path(@community), notice: "コミュニティの編集が完了しました!"
    else
      render "edit"
    end
  end

  def destroy
    @community.destroy
    redirect_to public_communities_path, alert: "コミュニティを削除しました!"
  end

  def leave
    owner = @community.owner
    owner.create_notification_leave(current_customer, @community.id)

    chat_room_customer = ChatRoomCustomer.find_by(
      customer_id: current_customer.id,
      community_id: @community.id
    )
    chat_room_customer&.destroy

    @community.customers.delete(current_customer)

    redirect_to public_communities_path, alert: "コミュニティを退会しました!"
  end

  def new_mail
  end

  def send_mail
    community_customers = @community.customers
    @mail_title = params[:mail_title]
    @mail_content = params[:mail_content]

    ContactMailer.send_mail(
      @mail_title,
      @mail_content,
      @community,
      community_customers
    ).deliver
  end

  def permits
    @permits = @community.permits.page(params[:page])
  end

  private

  def set_community
    @community = Community.find_by!(
      id: params[:id] || params[:community_id],
      domain_id: @current_domain.id
    )
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
      genre_ids: [],
    )
  end

  def ensure_correct_customer
    unless @community.owner_id == current_customer.id
      redirect_to public_communities_path, alert: "編集・削除する権限がありません。"
    end
  end

  def check_mail
    if params[:mail_title].blank? || params[:mail_content].blank?
      flash[:alert] = "タイトル、本文は必須です。"
      redirect_back(fallback_location: root_path)
    end
  end
end