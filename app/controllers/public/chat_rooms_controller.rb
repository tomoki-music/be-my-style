class Public::ChatRoomsController < ApplicationController
  before_action :authenticate_customer!
  include MatchingIndex
  before_action :matching_index, only: [:show]

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
    redirect_to public_chat_room_path(chat_room, customer_id: params[:customer_id])
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
    redirect_to community_show_public_chat_rooms_path(chat_room)
  end

  def community_show
    @chat_message = ChatMessage.new
    @chat_room = ChatRoom.find(params[:id])
    @customers = @chat_room.chat_room_customers.where(chat_room_id: @chat_room.id).map do |chat_room_customer|
      chat_room_customer.customer
    end
    @community = @chat_room.chat_room_customers.where(chat_room_id: @chat_room.id)[0].community
    @chat_messages = ChatMessage.where(chat_room_id: @chat_room.id)
    @chat_room_customer = @chat_room.chat_room_customers.where.not(customer_id: current_customer.id)[0].customer
  end

  private

end
