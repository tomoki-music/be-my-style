class Public::ChatMessagesController < ApplicationController
  before_action :authenticate_customer!

  def create
    @chat_room = ChatRoom.find(params[:chat_message][:chat_room_id])
    @chat_room_customer = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id)[0].customer
    @chat_message = ChatMessage.new(customer_id: current_customer.id, chat_room_id: @chat_room.id, content: params[:chat_message][:content])
    if @chat_message.save
        flash[:notice] = "メッセージを送信しました🎵"
        @chat_room_customer.create_notification_chat(current_customer)
        redirect_to public_chat_room_path(@chat_room)
    else
        flash[:alert] = "メッセージを入力してください！"
        redirect_to public_chat_room_path(@chat_room)
    end
  end
end
