class Public::ChatRoomsController < ApplicationController
  before_action :authenticate_customer!
  include MatchingIndex
  before_action :matching_index, only: [:show]

  def create
    current_customers_chat_rooms = ChatRoomCustomer.where(customer_id: current_customer.id).map do |chat_room_customer|
      chat_room_customer.chat_room
    end

    chat_room_customer = ChatRoomCustomer.where(chat_room_id: current_customers_chat_rooms, customer_id: params[:customer_id])[0]

    if chat_room_customer.present?
      chat_room = chat_room_customer.chat_room
    else
      chat_room = ChatRoom.create
      ChatRoomCustomer.create(customer_id: current_customer.id, chat_room_id: chat_room.id)
      ChatRoomCustomer.create(customer_id: params[:customer_id], chat_room_id: chat_room.id)
    end
    redirect_to public_chat_room_path(chat_room)
  end

  def show
    @chat_message = ChatMessage.new
    @chat_room = ChatRoom.find(params[:id])
    @chat_messages = ChatMessage.where(chat_room_id: @chat_room.id)
    @chat_room_customer = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id)[0].customer
  end

  private

end
