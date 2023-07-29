class CreateChatMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_messages do |t|
      t.references :chat_room, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.text :content
      t.bigint :community_id
      t.timestamps
    end
    add_index :chat_messages, :community_id
    add_foreign_key :chat_messages, :communities
  end
end
