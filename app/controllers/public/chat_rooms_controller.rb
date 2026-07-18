class Public::ChatRoomsController < ApplicationController
  before_action :authenticate_customer!
  include MatchingIndex
  before_action :matching_index, only: [:show]
  before_action :check_community_member, only: [:community_create]
  before_action only: [:create, :show, :mention_candidates] do
    require_feature!(:music_direct_chat, redirect_to_path: public_matchings_path)
  end
  before_action only: [:community_create, :community_mention_candidates] do
    require_feature!(:music_community_chat, redirect_to_path: public_communities_path)
  end

  def create
    current_customers_chat_rooms = ChatRoomCustomer.where(customer_id: current_customer.id).map do |chat_room_customer|
      chat_room_customer.chat_room
    end

    chat_room_customer = ChatRoomCustomer.where(chat_room_id: current_customers_chat_rooms, customer_id: params[:customer_id], community_id: nil)[0]

    if chat_room_customer.present?
      chat_room = chat_room_customer.chat_room
    else
      chat_room = ChatRoom.create
      ChatRoomCustomer.create(customer_id: current_customer.id, chat_room_id: chat_room.id)
      ChatRoomCustomer.create(customer_id: params[:customer_id], chat_room_id: chat_room.id)
    end
    redirect_to public_chat_room_path(chat_room, customer_id: params[:customer_id], anchor: message_anchor)
  end

  def show
    @chat_message = ChatMessage.new
    @chat_room = ChatRoom.find(params[:id])
    @chat_messages = ChatMessage.where(chat_room_id: @chat_room.id)
    @chat_room_customer = @chat_room.chat_room_customers.where(customer_id: params[:customer_id])[0].customer
  end

  def community_create
    current_customers_chat_rooms = ChatRoomCustomer.where(customer_id: current_customer.id).map do |chat_room_customer|
      chat_room_customer.chat_room
    end

    community_chat_room = ChatRoomCustomer.where(chat_room_id: current_customers_chat_rooms, community_id: params[:community_id])[0]

    if community_chat_room.present?
      chat_room = community_chat_room.chat_room
    else
      chat_room = ChatRoom.create
      ChatRoomCustomer.create(customer_id: current_customer.id, chat_room_id: chat_room.id, community_id: params[:community_id])
    end
    redirect_to community_show_public_chat_rooms_path(chat_room, anchor: message_anchor)
  end

  def community_show
    @chat_message = ChatMessage.new
    @chat_room = ChatRoom.find(params[:id])
    @customers = ChatRoomCustomer.where(chat_room_id: @chat_room.id).map do |chat_room_customer|
      chat_room_customer.customer
    end
    @community = ChatRoomCustomer.where(chat_room_id: @chat_room.id)[0].community
    @chat_messages = ChatMessage.where(chat_room_id: @chat_room.id)
  end

  # DM用メンション候補API。current_customerがこのchat_roomの参加者であることを
  # 必ず確認してから候補を返す(既存show/createには無いが、このAPIでは新規に検証する)。
  def mention_candidates
    chat_room = ChatRoom.find(params[:id])
    unless ChatRoomCustomer.where(chat_room_id: chat_room.id, customer_id: current_customer.id).exists?
      return render json: [], status: :forbidden
    end

    candidates = Chat::MentionCandidates.for_chat_room(
      chat_room: chat_room,
      current_customer: current_customer,
      query: params[:q]
    )
    render json: candidates.map { |customer| mention_candidate_json(customer) }
  rescue StandardError => e
    Rails.logger.error("[ChatRoomsController#mention_candidates] #{e.class}: #{e.message}")
    render json: { error: "候補を取得できませんでした" }, status: :unprocessable_entity
  end

  # コミュニティチャット用メンション候補API。実際のコミュニティメンバーシップ
  # (CommunityCustomer)で権限確認する(ChatRoomCustomerは全メンバーを網羅しないため使わない)。
  def community_mention_candidates
    community = Community.find(params[:community_id])
    unless CommunityCustomer.where(community_id: community.id, customer_id: current_customer.id).exists?
      return render json: [], status: :forbidden
    end

    candidates = Chat::MentionCandidates.for_community(
      community: community,
      current_customer: current_customer,
      query: params[:q]
    )
    render json: candidates.map { |customer| mention_candidate_json(customer) }
  rescue StandardError => e
    Rails.logger.error("[ChatRoomsController#community_mention_candidates] #{e.class}: #{e.message}")
    render json: { error: "候補を取得できませんでした" }, status: :unprocessable_entity
  end

  private

  def mention_candidate_json(customer)
    {
      id: customer.id,
      name: customer.name,
      avatar_url: mention_candidate_avatar_url(customer)
    }
  end

  def mention_candidate_avatar_url(customer)
    if customer.profile_image.attached?
      rails_blob_path(customer.profile_image, only_path: true)
    else
      helpers.asset_path("no_image.jpg")
    end
  end

  def message_anchor
    return nil if params[:chat_message_id].blank?

    "chat-message-#{params[:chat_message_id].to_i}"
  end

  def check_community_member
    unless ChatRoomCustomer.where(customer_id: current_customer.id, community_id: params[:community_id])[0].present?
      flash[:alert] = "コミュニティに参加していない為、チャットルームへ参加できません。"
      redirect_back(fallback_location: root_path)
    end
  end
end
