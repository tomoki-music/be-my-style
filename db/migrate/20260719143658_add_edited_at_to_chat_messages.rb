class AddEditedAtToChatMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_messages, :edited_at, :datetime
  end
end
