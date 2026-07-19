class Public::ChatMessagesController < ApplicationController
  before_action :authenticate_customer!
  before_action :chat_message_params, only: [:create, :community_create]
  before_action only: [:create] do
    require_feature!(:music_direct_chat, redirect_to_path: public_matchings_path)
  end
  before_action only: [:community_create] do
    require_feature!(:music_community_chat, redirect_to_path: public_communities_path)
  end

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
    @chat_message = ChatMessage.new(chat_message_params.except(:attachments, :reply_to_chat_message_id).merge(customer_id: current_customer.id, chat_room_id: @chat_room.id, content_format: :markdown, reply_to_chat_message: reply_to_chat_message))

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
    @chat_message = ChatMessage.new(chat_message_params.except(:attachments, :reply_to_chat_message_id).merge(customer_id: current_customer.id, chat_room_id: @chat_room.id, community_id: @community&.id, content_format: :markdown, reply_to_chat_message: reply_to_chat_message))

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

  private

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
    params.require(:chat_message).permit(:content, :stamp_type, :reply_to_chat_message_id, attachments: [])
  end
end
