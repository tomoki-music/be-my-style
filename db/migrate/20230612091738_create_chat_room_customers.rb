class CreateChatRoomCustomers < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_room_customers do |t|
      t.references :chat_room, foreign_key: true
      t.references :customer, foreign_key: true
      t.bigint :community_id
      t.timestamps
    end
    add_index :chat_room_customers, :community_id
    add_foreign_key :chat_room_customers, :communities
  end
end
