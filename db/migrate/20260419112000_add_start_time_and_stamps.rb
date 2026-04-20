class AddStartTimeAndStamps < ActiveRecord::Migration[6.1]
  def change
    add_column :songs, :performance_start_time, :string

    add_column :chat_messages, :stamp_type, :string
    add_column :comments, :stamp_type, :string
    add_column :requests, :stamp_type, :string
    add_column :messages, :stamp_type, :string
  end
end
