class AddContentFormatToChatMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_messages, :content_format, :integer, null: false, default: 0 # 0 = plain(既存メッセージは全て plain のまま)
  end
end
