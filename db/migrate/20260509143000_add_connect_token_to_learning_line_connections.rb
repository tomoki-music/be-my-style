class AddConnectTokenToLearningLineConnections < ActiveRecord::Migration[6.1]
  def change
    change_column_null :learning_line_connections, :line_user_id, true
    add_column :learning_line_connections, :connect_token, :string
    add_column :learning_line_connections, :expires_at, :datetime

    add_index :learning_line_connections, :connect_token, unique: true
    add_index :learning_line_connections, :expires_at
  end
end
