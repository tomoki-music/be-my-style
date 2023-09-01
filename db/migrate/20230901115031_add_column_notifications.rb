class AddColumnNotifications < ActiveRecord::Migration[6.1]
  def up
    add_column :notifications, :community_id, :integer
  end

  def down
    remove_column :notifications, :community_id, :integer
  end
end
