class AddColumnsToNotifications < ActiveRecord::Migration[6.1]
  def up
    add_column :notifications, :activity_id, :integer
  end

  def down
    remove_column :notifications, :activity_id, :integer
  end
end
