class Public::ChatMessagesController < ApplicationController
  before_action :authenticate_customer!

  def create
    @chat_room = ChatRoom.find(params[:chat_message][:chat_room_id])
    @chat_room_customer = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id)[0].customer
    @chat_message = ChatMessage.new(customer_id: current_customer.id, chat_room_id: @chat_room.id, content: params[:chat_message][:content])
    if @chat_message.save
        flash[:notice] = "メッセージを送信しました🎵"
        @chat_room_customer.create_notification_chat(current_customer)
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
    @chat_message = ChatMessage.new(customer_id: current_customer.id, chat_room_id: @chat_room.id, content: params[:chat_message][:content])
    if @chat_message.save
      @chat_room_customers.each do |chat_room_customer|
        chat_room_customer.create_notification_chat(current_customer)
      end
      flash[:notice] = "メッセージを送信しました！"
      redirect_back(fallback_location: root_path)
    else
      flash[:alert] = "メッセージを入力してください！"
      redirect_back(fallback_location: root_path)
    end
  end
end
