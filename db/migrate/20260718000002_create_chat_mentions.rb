class CreateChatMentions < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_mentions do |t|
      t.references :chat_message, null: false, foreign_key: true
      t.references :mentioned_customer, null: false, foreign_key: { to_table: :customers }

      t.timestamps
    end

    add_index :chat_mentions, [:chat_message_id, :mentioned_customer_id],
              unique: true, name: "index_chat_mentions_on_message_and_customer"
  end
end
