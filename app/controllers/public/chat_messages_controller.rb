class Public::ChatMessagesController < ApplicationController
  def create
    @chat_room = ChatRoom.find(params[:chat_message][:chat_room_id])
    @chat_message = ChatMessage.new(customer_id: current_customer.id, chat_room_id: @chat_room.id, content: params[:chat_message][:content])
    if @chat_message.save
        flash[:notice]="メッセージを送信しました。"
        redirect_to public_chat_room_path(@chat_room)
    else
        flash[:alert]="メッセージの送信に失敗しました。"
        redirect_to public_chat_room_path(@chat_room)
    end
  end
end
