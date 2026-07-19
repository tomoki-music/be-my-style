class Public::ChatMessagesController < ApplicationController
  before_action :authenticate_customer!
  before_action :chat_message_params, only: [:create, :community_create]
  before_action only: [:create] do
    require_feature!(:music_direct_chat, redirect_to_path: public_matchings_path)
  end
  before_action only: [:community_create] do
    require_feature!(:music_community_chat, redirect_to_path: public_communities_path)
  end

  THREAD_REPLIES_LIMIT = 50

  def create
    @chat_room = ChatRoom.find(params[:chat_message][:chat_room_id])
    unless Chat::ChatRoomAuthorization.postable?(chat_room: @chat_room, community: nil, customer: current_customer)
      flash[:alert] = "このチャットルームへ参加していません。"
      return redirect_to root_path
    end

    @chat_room_customer = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id)[0].customer
    reply_to_chat_message = Chat::ReplyTargetResolver.call(
      reply_to_chat_message_id: chat_message_params[:reply_to_chat_message_id],
      chat_room: @chat_room,
      community: nil,
      current_customer: current_customer
    )
    quoted_chat_message = Chat::QuoteTargetResolver.call(
      quoted_chat_message_id: chat_message_params[:quoted_chat_message_id],
      chat_room: @chat_room,
      community: nil,
      current_customer: current_customer
    )
    @chat_message = ChatMessage.new(chat_message_params.except(:attachments, :reply_to_chat_message_id, :quoted_chat_message_id).merge(customer_id: current_customer.id, chat_room_id: @chat_room.id, content_format: :markdown, reply_to_chat_message: reply_to_chat_message, quoted_chat_message: quoted_chat_message))

    if params[:chat_message][:attachments].present?
      params[:chat_message][:attachments].each do |uploaded_file|
        @chat_message.attachments.attach(uploaded_file)
      end
    end

    if save_chat_message_with_replies_and_mentions(@chat_message)
        flash[:notice] = "メッセージを送信しました🎵"
        @chat_room_customer.create_notification_chat(current_customer)
        CustomerMailer.with(ac_customer: current_customer, ps_customer: @chat_room_customer, chat_message: @chat_message).create_chat_mail.deliver_later
        redirect_to public_chat_room_path(@chat_room, customer_id: @chat_room_customer.id)
    else
        flash[:alert] = "メッセージを入力してください！"
        redirect_to public_chat_room_path(@chat_room, customer_id: @chat_room_customer.id)
    end
  end

  def community_create
    @chat_room = ChatRoom.find(params[:chat_message][:chat_room_id])
    @chat_room_customers = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id).map do |chat_room_customer|
      chat_room_customer.customer
    end
    @community = ChatRoomCustomer.where(chat_room_id: @chat_room.id)[0].community

    unless Chat::ChatRoomAuthorization.postable?(chat_room: @chat_room, community: @community, customer: current_customer)
      flash[:alert] = "コミュニティに参加していない為、投稿できません。"
      return redirect_back(fallback_location: root_path)
    end

    # community_idは元々どこにも設定されておらず常にnilだった(既存のバグ)。
    # @メンション機能がDM/コミュニティチャットを判定する唯一の手がかりとして使うため、
    # ここで明示的に設定する(他にこのカラムを参照する既存コードはないため後方互換に影響しない)。
    reply_to_chat_message = Chat::ReplyTargetResolver.call(
      reply_to_chat_message_id: chat_message_params[:reply_to_chat_message_id],
      chat_room: @chat_room,
      community: @community,
      current_customer: current_customer
    )
    quoted_chat_message = Chat::QuoteTargetResolver.call(
      quoted_chat_message_id: chat_message_params[:quoted_chat_message_id],
      chat_room: @chat_room,
      community: @community,
      current_customer: current_customer
    )
    @chat_message = ChatMessage.new(chat_message_params.except(:attachments, :reply_to_chat_message_id, :quoted_chat_message_id).merge(customer_id: current_customer.id, chat_room_id: @chat_room.id, community_id: @community&.id, content_format: :markdown, reply_to_chat_message: reply_to_chat_message, quoted_chat_message: quoted_chat_message))

    if params[:chat_message][:attachments].present?
      params[:chat_message][:attachments].each do |uploaded_file|
        @chat_message.attachments.attach(uploaded_file)
      end
    end

    if save_chat_message_with_replies_and_mentions(@chat_message)
      @chat_room_customers.each do |chat_room_customer|
        if current_customer != chat_room_customer
          chat_room_customer.create_notification_group_chat(current_customer, @community.id)
          if chat_room_customer.confirm_mail
            CustomerMailer.with(ac_customer: current_customer, ps_customer: chat_room_customer, community: @community, chat_message: @chat_message).create_group_chat_mail.deliver_later
          end
        end
      end
      flash[:notice] = "メッセージを送信しました！"
      redirect_back(fallback_location: root_path)
    else
      flash[:alert] = "メッセージを入力してください！"
      redirect_back(fallback_location: root_path)
    end
  end

  # Markdownプレビュー用。DBへの書き込みは一切行わない。
  # 文字数上限はChat::MarkdownRenderer::MAX_LENGTHで一元管理し、実際の投稿表示と揃える。
  def preview
    render json: { html: Chat::MarkdownRenderer.call(params[:content]) }
  rescue StandardError => e
    Rails.logger.error("[Chat::MarkdownRenderer preview] #{e.class}: #{e.message}")
    render json: { error: "プレビューを生成できませんでした" }, status: :unprocessable_entity
  end

  # スレッド(元メッセージ+返信一覧)をHTML断片として返す。ページ全体を再読み込みせず、
  # スレッドパネルへfetchで挿入する用途。params[:id]は返信メッセージのIDでもよく、
  # その場合はスレッドの親(thread_root)まで遡って表示する。
  def thread
    target = ChatMessage.find_by(id: params[:id])
    return head :not_found if target.blank?

    root = target.thread_root
    community = community_for_chat_room(root.chat_room)
    return head :forbidden unless thread_readable?(root, community)

    replies = root.replies
              .includes(:customer, :mentioned_customers, reply_to_chat_message: :customer, quoted_chat_message: :customer)
              .with_attached_attachments
              .order(created_at: :asc)
              .limit(THREAD_REPLIES_LIMIT)

    render partial: "public/chat_rooms/thread_panel_content",
           locals: { root_message: root, replies: replies },
           layout: false
  end

  # スレッドへの返信を投稿する。親メッセージID(params[:id])はURLから取得し、
  # クライアントから任意のreply_to_chat_message_idを受け付けない
  # (通常投稿と違い、返信先を偽装できないようにする)。
  # 成功時はJSONで新規メッセージのHTML断片と最新の返信件数を返し、スレッドパネル・
  # 通常一覧側の「N件の返信」表示の両方をJS側で即時更新できるようにする。
  def thread_reply
    target = ChatMessage.find_by(id: params[:id])
    return render_thread_reply_error(:not_found) if target.blank?

    root = target.thread_root
    community = community_for_chat_room(root.chat_room)
    return render_thread_reply_error(:forbidden) unless thread_postable?(root, community)

    reply_to_chat_message = Chat::ReplyTargetResolver.call(
      reply_to_chat_message_id: root.id,
      chat_room: root.chat_room,
      community: community,
      current_customer: current_customer
    )
    return render_thread_reply_error(:forbidden) if reply_to_chat_message.blank?

    quoted_chat_message = Chat::QuoteTargetResolver.call(
      quoted_chat_message_id: thread_reply_params[:quoted_chat_message_id],
      chat_room: root.chat_room,
      community: community,
      current_customer: current_customer
    )

    @chat_message = ChatMessage.new(
      thread_reply_params.except(:attachments, :quoted_chat_message_id).merge(
        customer_id: current_customer.id,
        chat_room_id: root.chat_room_id,
        community_id: community&.id,
        content_format: :markdown,
        reply_to_chat_message: reply_to_chat_message,
        quoted_chat_message: quoted_chat_message
      )
    )

    if params[:chat_message] && params[:chat_message][:attachments].present?
      params[:chat_message][:attachments].each do |uploaded_file|
        @chat_message.attachments.attach(uploaded_file)
      end
    end

    if save_chat_message_with_replies_and_mentions(@chat_message)
      html = render_to_string(
        partial: "public/chat_rooms/message",
        locals: { chat_message: @chat_message, display_context: :thread },
        layout: false
      )
      render json: { html: html, replies_count: root.reload.replies_count, root_message_id: root.id }, status: :ok
    else
      render json: { errors: @chat_message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # DM参加者・コミュニティ参加権限に加え、そのチャット種別のプラン機能(feature)が
  # 有効であることも確認する(通常投稿と同じ権限水準をスレッド取得・投稿にも適用する)。
  def thread_readable?(root, community)
    return false if root.blank?
    return false unless thread_feature_enabled?(community)

    Chat::ChatRoomAuthorization.readable?(chat_room: root.chat_room, community: community, customer: current_customer)
  end

  def thread_postable?(root, community)
    return false if root.blank?
    return false unless thread_feature_enabled?(community)

    Chat::ChatRoomAuthorization.postable?(chat_room: root.chat_room, community: community, customer: current_customer)
  end

  def thread_feature_enabled?(community)
    feature_key = community.present? ? :music_community_chat : :music_direct_chat
    current_customer.has_feature?(feature_key)
  end

  # root.community(ChatMessage#community_id)は「元々どこにも設定されておらず常にnilだった
  # (既存のバグ)」経緯があり、過去に作成されたコミュニティメッセージではnilのまま残っている
  # ことがある。このためroot.communityをそのまま信用すると、過去のコミュニティメッセージを
  # スレッドrootとする操作でDM(music_direct_chat)扱いになり、権限判定を誤る。
  # community_create/community_showと同様、ChatRoomCustomer(信頼できる方の関連)から
  # 実際のコミュニティを導出する。
  def community_for_chat_room(chat_room)
    ChatRoomCustomer.where(chat_room_id: chat_room.id).where.not(community_id: nil).first&.community
  end

  def render_thread_reply_error(status)
    render json: { errors: ["操作できませんでした"] }, status: status
  end

  def thread_reply_params
    params.require(:chat_message).permit(:content, :stamp_type, :quoted_chat_message_id, attachments: [])
  end

  # メッセージ保存と返信通知・メンション(ChatMention・通知)作成を1トランザクションにまとめる。
  # 保存に失敗した場合はもちろん、通知作成中に例外が起きた場合もメッセージごと
  # ロールバックされるため、ChatMentionだけが残ることはない。
  # 返信通知を先に作成し、通知済み相手へのメンション通知はMentionSyncServiceで抑制する
  # (同一メッセージ・同一相手への「返信」「メンション」の重複通知を避けるため)。
  def save_chat_message_with_replies_and_mentions(chat_message)
    ActiveRecord::Base.transaction do
      raise ActiveRecord::Rollback unless chat_message.save

      reply_notified_ids = Chat::ReplyNotificationService.call(chat_message)
      Chat::MentionSyncService.call(chat_message, skip_notification_customer_ids: reply_notified_ids)
      true
    end || false
  end

  def chat_message_params
    params.require(:chat_message).permit(:content, :stamp_type, :reply_to_chat_message_id, :quoted_chat_message_id, attachments: [])
  end
end
