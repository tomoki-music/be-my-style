class AddChatMessageToNotifications < ActiveRecord::Migration[6.1]
  def change
    add_reference :notifications, :chat_message, null: true, foreign_key: true
  end
end
