class CreateChatRoomCustomers < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_room_customers do |t|
      t.references :chat_room, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.timestamps
    end
  end
end
