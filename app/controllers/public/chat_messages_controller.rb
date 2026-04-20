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
    @chat_room_customer = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id)[0].customer
    @chat_message = ChatMessage.new(chat_message_params.except(:attachments).merge(customer_id: current_customer.id, chat_room_id: @chat_room.id))

    if params[:chat_message][:attachments].present?
      params[:chat_message][:attachments].each do |uploaded_file|
        @chat_message.attachments.attach(uploaded_file)
      end
    end

    if @chat_message.save
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
    @chat_message = ChatMessage.new(chat_message_params.except(:attachments).merge(customer_id: current_customer.id, chat_room_id: @chat_room.id))
    
    if params[:chat_message][:attachments].present?
      params[:chat_message][:attachments].each do |uploaded_file|
        @chat_message.attachments.attach(uploaded_file)
      end
    end
    
    if @chat_message.save
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

  private

  def chat_message_params
    params.require(:chat_message).permit(:content, :stamp_type, attachments: [])
  end
end
