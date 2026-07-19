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
    redirect_to public_chat_room_path(chat_room, customer_id: params[:customer_id], **jump_params)
  end

  def show
    @chat_room = ChatRoom.find_by(id: params[:id])
    return render_chat_room_not_found if @chat_room.blank?

    unless Chat::ChatRoomAuthorization.readable?(chat_room: @chat_room, community: nil, customer: current_customer)
      return render_chat_room_not_found
    end

    @chat_message = ChatMessage.new
    # スレッドの返信はここでは表示せず、親メッセージのみを表示する(返信はスレッドパネルで確認する)。
    # 親メッセージは常にreply_to_chat_message_idがnilなので、reply_to_chat_messageのincludesは不要。
    @chat_messages = ChatMessage.thread_roots.where(chat_room_id: @chat_room.id)
      .includes(:customer, quoted_chat_message: :customer)
      .with_attached_attachments
    # 相手の情報は、クライアントが指定できるparams[:customer_id]ではなく、current_customer
    # 基準で「このchat_roomのもう一方の参加者」を導出する(不正または欠落したcustomer_idで
    # 壊れないようにするため。DMのchat_roomは常に2名の参加者を持つ設計)。
    @chat_room_customer = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id)[0].customer
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
    redirect_to community_show_public_chat_rooms_path(chat_room, **jump_params)
  end

  def community_show
    @chat_room = ChatRoom.find_by(id: params[:id])
    return render_chat_room_not_found if @chat_room.blank?

    # このchat_roomが実際にコミュニティへ紐づいていることをChatRoomCustomer側の実データで
    # 確認する。紐づきが無ければ(例: DM用chat_roomのIDをcommunity_showへ直接指定された場合)
    # コミュニティとして閲覧させない。
    @community = ChatRoomCustomer.where(chat_room_id: @chat_room.id).where.not(community_id: nil).first&.community
    return render_chat_room_not_found if @community.blank?

    unless Chat::ChatRoomAuthorization.readable?(chat_room: @chat_room, community: @community, customer: current_customer)
      return render_chat_room_not_found
    end

    @chat_message = ChatMessage.new
    @customers = ChatRoomCustomer.where(chat_room_id: @chat_room.id).map do |chat_room_customer|
      chat_room_customer.customer
    end
    # スレッドの返信はここでは表示せず、親メッセージのみを表示する(返信はスレッドパネルで確認する)。
    @chat_messages = ChatMessage.thread_roots.where(chat_room_id: @chat_room.id)
      .includes(:customer, quoted_chat_message: :customer)
      .with_attached_attachments
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

  # 通知経由の遷移先を決定する。対象メッセージが通常投稿(スレッド親)ならページ内アンカーへ、
  # スレッド内の返信(reply_dm/reply_community、または返信自体へのmention)なら
  # スレッドパネルを自動で開いて対象をハイライトするクエリパラメータへ変換する
  # (返信は通常一覧に表示されないため、アンカーでは辿り着けない)。
  def jump_params
    return {} if params[:chat_message_id].blank?

    target = ChatMessage.find_by(id: params[:chat_message_id])
    return {} if target.blank?

    if target.reply_to_chat_message_id.present?
      { thread_message_id: target.thread_root.id, highlight_message_id: target.id }
    else
      { anchor: "chat-message-#{target.id}" }
    end
  end

  # コミュニティ参加権限はCommunityCustomer(実際のコミュニティメンバーシップ)で判定する。
  # 以前はChatRoomCustomerの存在で判定していたが、これは「初めてそのコミュニティの
  # チャットルームへ入室する(=まだChatRoomCustomer行が無い)」場合にも常に弾いてしまう
  # 論理矛盾のあるチェックだったため修正した。
  def check_community_member
    unless CommunityCustomer.where(customer_id: current_customer.id, community_id: params[:community_id]).exists?
      flash[:alert] = "コミュニティに参加していない為、チャットルームへ参加できません。"
      redirect_back(fallback_location: root_path)
    end
  end

  # 存在しないchat_room・非参加者・未参加コミュニティの全てで同一のレスポンス(404)を返す。
  # 「存在するが権限が無い」と「存在しない」を区別すると、他人のDM/コミュニティの
  # chat_room IDが実在するかどうかを外部から推測できてしまうため、常に同じ応答にする。
  def render_chat_room_not_found
    head :not_found
  end
end
