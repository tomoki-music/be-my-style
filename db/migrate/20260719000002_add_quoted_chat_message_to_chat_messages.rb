class AddQuotedChatMessageToChatMessages < ActiveRecord::Migration[6.1]
  def change
    add_reference :chat_messages, :quoted_chat_message,
                   null: true,
                   foreign_key: { to_table: :chat_messages },
                   index: true
  end
end
